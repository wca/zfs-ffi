require 'test_helper'

class TestBasic < Test::Unit::TestCase
  def geom_disks
    diskname = nil
    lines = `geom disk list 2>/dev/null`.split("\n") rescue []
    lines.inject({}) do |hsh, line|
      if line =~ /^Geom name: ([a-z]+\d+)/
        diskname = $1
      elsif line =~ /^   Mode: r(\d)w(\d)e(\d)/
        raise "Error parsing geom: found mode without a disk" unless diskname
        hsh[diskname] = {
          :name => diskname,
          :rd => $1.to_i, :wr => $2.to_i, :ex => $3.to_i
        }
        diskname = nil
      end
      hsh
    end
  end

  def run_cmd(cmd)
    puts "Running: #{cmd}" if ENV["DEBUG"]
    system cmd or raise "Command failed!"
  end

  def setup
    avail_disk = geom_disks.find do |name, h|
      !(name =~ /da\d+$/).nil? && (h[:rd] + h[:wr] + h[:ex]).zero?
    end
    raise "Can't find an available disk to use" unless avail_disk
    @poolname = "#{self.class.name}"
    system "zpool destroy -f #{@poolname} 2>/dev/null"
    run_cmd "zpool create -f #{@poolname} #{avail_disk[0]}"
  end

  def teardown
    run_cmd "zpool destroy -f #{@poolname}"
  end

  def test_zfs_pool_lookup_works
    pool = nil
    ZFS::Pool.each {|p| pool = p if p.name == @poolname}
    puts "pool=#{pool.inspect}"
    assert(!pool.nil?)
  end
end
