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

  def pool_setup(type=:stripe, top_levels=1, leaves=1)
    skip("Must run ZFS pool tests as root!") unless Process.uid.zero?
    @memdisks = []
    required_disk_count = top_levels * leaves

    avail_disks = available_disks
    if avail_disks.size < required_disk_count
      $stderr.puts "Insufficient geom disks available, trying memory disks..."

      avail_disks = (1..required_disk_count).collect do |i|
        disk = `mdconfig -a -t malloc -s 64m 2>/dev/null`.strip
        if disk.empty?
          raise "Unable to autocreate a disk for the temporary pool"
        end
        disk
      end
      @memdisks = avail_disks
    end

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
