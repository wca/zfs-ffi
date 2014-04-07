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

  def run_cmd(cmd)
    $stderr.puts "Running: #{cmd}" if ENV["DEBUG"]
    system(cmd)
    raise "Command #{cmd.inspect} failed!" unless $?.success?
  end

  def pool_setup
    skip("Must run ZFS pool tests as root!") unless Process.uid.zero?

    avail_disk = available_disks.first
    if avail_disk.nil?
      $stderr.puts "No geom disks available, trying memory disk..."
      avail_disk = `mdconfig -a -t malloc -s 1g 2>/dev/null`
      if avail_disk.empty?
        raise "Unable to autodetect a disk for the temporary pool"
      end
      @memdisk = avail_disk
    end

    begin
      poolname = "#{self.class.name}_#{SecureRandom.urlsafe_base64(12)}"
      run_cmd("zpool create #{poolname} #{avail_disk}")
      @pool = ZFS::Pool.find_by_name(poolname)
      @pool_fs = ZFS::FS.new(@pool.name)
      yield if block_given?
    rescue StandardError => e
      pool_teardown
      raise
    end
  end

  def pool_teardown
    run_cmd("zpool destroy -f #{@pool.name}") if @pool
    run_cmd("mdconfig -d -u #{@memdisk}") if @memdisk
  end
end
