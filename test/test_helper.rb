require 'securerandom'
require 'test/unit'
# required for class/module-level stubs.
require 'mocha/setup'

require 'zfs'

class Object
  def metaclass
    class << self
      self
    end
  end
end

# Common routines for ZFS tests.  Include this module in every test class to
# get access to these as instance methods.
module ZFSTest
  def geom_disks
    diskname = nil
    (`geom disk list 2>/dev/null`.split("\n") rescue []).inject({}) do |hsh, l|
      if l =~ /^Geom name: ([a-z]+\d+)/
        diskname = $1
      elsif l =~ /^   Mode: r(\d)w(\d)e(\d)/
        raise "Error parsing geom: found mode without a disk" if diskname.nil?
        hsh[diskname] = {
          :name => diskname,
          :rd => $1.to_i, :wr => $2.to_i, :ex => $3.to_i
        }
        diskname = nil
      end
      hsh
    end
  end

  def available_disks
    geom_disks.inject([]) do |r, g|
      name, h = g
      if !name.match(/da\d+$/).nil? && (h[:rd] + h[:wr] + h[:ex]).zero?
        r << name
      else
        r
      end
    end
  end

  def run_cmd(cmd, ignore_error=false)
    $stderr.puts "Running: #{cmd}" if ENV["DEBUG"]
    system(cmd)
    unless ignore_error
      raise "Command #{cmd.inspect} failed!" unless $?.success?
    end
  end

  # Return an array of n disks that may be used for the test
  def choose_disks(n)
    avail_disks = available_disks
    if avail_disks.size < n
      $stderr.puts "Insufficient geom disks available, trying memory disks..."

      avail_disks = (1..n).collect do |i|
        disk = `mdconfig -a -t malloc -s 64m 2>/dev/null`.strip
        if disk.empty?
          raise "Unable to autocreate a disk for the temporary pool"
        end
        disk
      end
      @memdisks = avail_disks
    end
    avail_disks
  end

  # Create a pool with type stripe, mirror, or raidz[123] with a certain number
  # of top level vdevs and leaf vdevs per top level vdev.  It may also have
  # log, cache, and spare devices.  In general, the slogs and caches could have
  # a configuration as complicated as the basic vdevs, but this method supports
  # only stripes for slogs and caches.
  def pool_setup(type=:stripe, top_levels=1, leaves=1, slogs=0, caches=0, spares=0)
    skip("Must run ZFS pool tests as root!") unless Process.uid.zero?
    @memdisks = []
    required_disk_count = top_levels * leaves + slogs + caches + spares

    avail_disks = choose_disks(required_disk_count)

    begin
      @poolname = "#{self.class.name}_#{SecureRandom.urlsafe_base64(12)}"
      if type == :stripe
        stripe_disks = avail_disks[0..(leaves - 1)].join(' ')
        # Use -f in case the disks have different sizes
        run_cmd("zpool create -f #{@poolname} #{stripe_disks}")
      elsif [:mirror, :raidz1, :raidz2, :raidz3].include? type
        vdev_spec = ""
        (0..(top_levels-1)).each do |i|
          stripe_disks = avail_disks[(leaves * i)..(leaves * (i+1) - 1)]
          vdev_spec <<= "#{type.to_s} #{stripe_disks.join(' ')} "
        end
        # Use -f in case the disks have different sizes
        run_cmd("zpool create -f #{@poolname} #{vdev_spec}")
      else
        raise "Unknown vdev type #{type}"
      end
      if slogs > 0
        # Slog devices are normally mirrored or raid-10
        mode =  slogs > 1 ? "mirror" : ""
        skip = leaves * top_levels
        log_disks = avail_disks[skip..(skip + slogs - 1)]
        vdev_spec = "log #{mode} #{log_disks.join(' ')}"
        run_cmd("zpool add #{@poolname} #{vdev_spec}")
      end
      if caches > 0
        skip = leaves * top_levels + slogs
        log_disks = avail_disks[skip..(skip + caches - 1)]
        vdev_spec = "cache #{log_disks.join(' ')}"
        run_cmd("zpool add #{@poolname} #{vdev_spec}")
      end
      if spares > 0
        skip = leaves * top_levels + slogs + caches
        log_disks = avail_disks[skip..(skip + spares - 1)]
        vdev_spec = "spare #{log_disks.join(' ')}"
        run_cmd("zpool add #{@poolname} #{vdev_spec}")
      end

      ZFS.reopen
      @pool = ZFS::Pool.find_by_name(@poolname)
      @pool_fs = ZFS::FS.new(@pool.name)
      yield if block_given?
    rescue StandardError => e
      pool_teardown
      raise
    end
  end

  def pool_teardown
    run_cmd("zpool destroy -f #{@poolname}", true) if @poolname
    @memdisks.each do |memdisk|
      run_cmd("mdconfig -d -u #{memdisk}")
    end
  end
end
