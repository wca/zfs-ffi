require 'test_helper'
require 'set'

class TestBasic < Test::Unit::TestCase
  include ZFSTest

  def setup
    pool_setup
  end

  def teardown
    pool_teardown
  end

  def test_open_pool
    assert_raise NoMethodError do
      h = ZFS::Handle.open
      pool = ZFS::Pool.new(@poolname, h)
    end
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_not_nil(pool)
    assert_equal(@poolname, pool.name)
  end

  def test_refresh_props
    parent = ZFS::FS.create("#{@pool_fs.name}/parent")
    child = ZFS::FS.create("#{@pool_fs.name}/parent/child")
    parent.refresh
    new_parent_instance = ZFS::FS.new("#{@pool_fs.name}/parent")
    assert_equal(parent.properties, new_parent_instance.properties)
  end

  def test_zfs_children_traversal
    fs = %W(root0 root0/bar root1 root0/bar/0 root0/baz).inject({}) do |fs, n| 
      fs[n] = ZFS::FS.create("#{@pool_fs.name}/#{n}")
      fs
    end
    # Refresh the status of every object.
    fs.each_value {|v| v.refresh}

    expected = Set.new(["#{@pool_fs.name}/root0/bar", "#{@pool_fs.name}/root0/baz"])
    actual = Set.new(fs["root0"].children.collect {|c| c.name})
    assert_equal(expected, actual,
      "root0 should have only children root0/bar and root0/baz")
    expected = ["#{@pool_fs.name}/root0/bar/0"]
    actual = fs["root0/bar"].children.collect {|c| c.name}
    assert_equal(expected, actual, "root0/bar should have only children root0/bar/0")
    assert_equal([], fs["root1"].children, "root1 should have no children")
  end

  def test_zfs_property_lookups
    assert_equal("filesystem", @pool_fs.type.value,
                 "Pool root should be a filesystem")

    creation_diff = Time.now.to_i - @pool_fs.creation.value
    assert(creation_diff < 60, "Pool root should be recently created")

    assert_equal("1.00x", @pool_fs.compressratio.value,
      "Pool root should have a compress ratio of 1.0")
    assert_equal("yes", @pool_fs.mounted.value, "Pool root should be mounted")

    %W(used recordsize guid copies version).each do |propname|
      assert(@pool_fs.send(propname).value.is_a?(Integer),
        "Property #{propname} should be an integer")
    end
  end
end


class TestFsProperties < Test::Unit::TestCase
  include ZFSTest

  def setup
    pool_setup
  end

  def teardown
    pool_teardown
  end

  # Set a user property on a filesystem and verify that ruby can read it
  # correctly
  def test_user_prop
    propname="com.spectralogic:test_user_prop"
    propval="foo"
    run_cmd("zfs set #{propname}=#{propval} #{@pool_fs.name}")
    @pool_fs.refresh
    assert(@pool_fs.properties[propname].is_a? ZFS::Property)
    assert_equal(propval, @pool_fs.properties[propname].value)
    assert_equal("local", @pool_fs.properties[propname].source)
  end

  # Set a user property on a filesystem and verify that ruby can read it
  # correctly from a child filesystem
  def test_inherited_user_prop
    propname="com.spectralogic:test_user_prop"
    propval="foo"
    childname="#{@pool_fs.name}/child"
    run_cmd("zfs set #{propname}=#{propval} #{@pool_fs.name}")
    run_cmd("zfs create #{childname}")
    child_fs = ZFS::FS.new(childname)
    assert(child_fs.properties[propname].is_a? ZFS::Property)
    assert_equal(propval, child_fs.properties[propname].value)
    assert_equal("inherited from #{@pool_fs.name}",
                 child_fs.properties[propname].source)
  end
end


class TestPoolProperties < Test::Unit::TestCase
  include ZFSTest

  def setup
    pool_setup
  end

  def teardown
    pool_teardown
  end

  # Test that any feature properties have the correct format
  def test_features
    allprops = `zpool get all #{@poolname}`
    allprops.each_line do |line|
      poolname, propname, value, source = line.split
      next unless propname =~ /^feature@/
      assert( @pool.properties.keys.include?(propname) )
      assert_equal(value, @pool.properties[propname].value)
      assert_equal(source, @pool.properties[propname].source)
    end
  end

  # Test that we can lookup numeric properties, and that they are sane.
  def test_numbers
    all_numeric_props = %w(size free freeing allocated expandsize capacity guid
                           dedupratio version dedupditto)
    properties = @pool.properties
    all_numeric_props.each do |prop|
      assert(properties[prop].value.is_a?(Integer), "prop #{prop} had the wrong type")
    end
    # Sanity check a few values
    
    # Allocated + free == size
    assert_equal(properties['size'].value,
                 properties['allocated'].value + properties['free'].value)

    # Version should be 1-28 or 5000 (if feature flags are enabled)
    assert(properties['version'].value <= 28 || properties['version'].value == 5000)

    # The kernel rather foolishly transforms dedupratio into a percentage
    assert(properties['dedupratio'].value >= 100)
  end

  # The health property is very very special
  def test_health
    assert_equal("ONLINE", @pool.properties["health"].value)
  end

  def test_hidden_props
    all_hidden_props = %w(name)
    assert_equal(@poolname, @pool.properties["name"].value)
  end

  def test_index_props
    boolean_index_props = %w(delegation autoreplace listsnapshots autoexpand
                             readonly)
    other_index_props = %w(failmode)
    all_index_props = boolean_index_props + other_index_props
    all_index_props.each do |prop|
      assert(@pool.properties[prop].value.is_a? String)
    end

    # Sanity check a few values
    boolean_index_props.each do |prop|
      assert(["on", "off"].include? @pool.properties[prop].value)
    end

    assert(["wait", "continue", "panic"].include? @pool.properties["failmode"].value)
  end

  def test_strings
    all_string_props = %w(altroot bootfs cachefile comment)
    all_string_props.each do |prop|
      assert(@pool.properties[prop].value.is_a? String)
    end
  end

end


class TestPoolRedundancy < Test::Unit::TestCase
  include ZFSTest

  def teardown
    pool_teardown
  end

  def test_single_disk
    pool_setup(:stripe, 1, 1)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal(0, pool.redundancy_level)
  end

  def test_2way_mirror
    pool_setup(:mirror, 1, 2)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal(1, pool.redundancy_level)
  end

  def test_3way_mirror
    pool_setup(:mirror, 1, 3)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal(2, pool.redundancy_level)
  end

  def test_raidz1
    pool_setup(:raidz1, 1, 3)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal(1, pool.redundancy_level)
  end

  def test_raidz2
    pool_setup(:raidz2, 1, 3)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal(2, pool.redundancy_level)
  end

  def test_raidz3
    pool_setup(:raidz3, 1, 4)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal(3, pool.redundancy_level)
  end

  def test_striped_raidz1
    pool_setup(:raidz1, 2, 3)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal(1, pool.redundancy_level)
  end

  def test_asymetric_stripes
    # Create a striped 3-disk raidz1 and 3-disk raidz2
    n = 6
    skip("Must run ZFS pool tests as root!") unless Process.uid.zero?
    @memdisks = []
    avail = choose_disks(n)
    begin
      @poolname = "#{self.class.name}_#{SecureRandom.urlsafe_base64(12)}"
      vdev_spec = "raidz2 #{avail[0]} #{avail[1]} #{avail[2]} " + \
                  "raidz1 #{avail[3]} #{avail[4]} #{avail[5]}"
      run_cmd("zpool create -f #{@poolname} #{vdev_spec}")
      ZFS.reopen
      @pool = ZFS::Pool.find_by_name(@poolname)
    rescue StandardError => e
      pool_teardown
      raise
    end
    assert_equal(1, @pool.redundancy_level)
  end

  def test_zil
    pool_setup(:raidz2, 1, 3, 2, 0, 0)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal(1, pool.redundancy_level)
  end

  # L2Arc devices should never count towards the limit; they're only cache
  def test_l2arc
    pool_setup(:raidz2, 1, 3, 0, 1, 0)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal(2, pool.redundancy_level)
  end
end


class TestPoolTopology < Test::Unit::TestCase
  include ZFSTest

  def teardown
    pool_teardown
  end

  def test_mirror
    pool_setup(:mirror, 1, 2)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal("root", pool.root_vdev.type)
    assert_equal(1, pool.root_vdev.children.count)
    assert_equal("mirror", pool.root_vdev.children.first.type)
    assert_equal(2, pool.root_vdev.children.first.children.count)
    pool.root_vdev.children.first.children.each do |child|
      assert_equal("disk", child.type)
    end
  end

  def test_single_disk
    pool_setup(:stripe, 1, 1)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal("root", pool.root_vdev.type)
    assert_equal(1, pool.root_vdev.children.count)
    assert_equal(0, pool.root_vdev.children.first.children.count)
    assert_equal("disk", pool.root_vdev.children.first.type)
  end

  # TODO: implement Device#name based on zpool_vdev_name
  def test_raidz
    pool_setup(:raidz1, 1, 3)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal("root", pool.root_vdev.type)
    assert_equal(1, pool.root_vdev.children.count)
    assert_equal("raidz", pool.root_vdev.children.first.type)
    assert_equal("raidz1", pool.root_vdev.children.first.name(false))
    assert_equal("raidz1-0", pool.root_vdev.children.first.name(true))
    assert_equal(1, pool.root_vdev.children.first.nparity)
    assert_equal(3, pool.root_vdev.children.first.children.count)
    pool.root_vdev.children.first.children.each do |child|
      assert_equal("disk", child.type)
    end
  end

  def test_raidz2
    pool_setup(:raidz2, 1, 4)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal("root", pool.root_vdev.type)
    assert_equal(1, pool.root_vdev.children.count)
    assert_equal("raidz", pool.root_vdev.children.first.type)
    assert_equal("raidz2", pool.root_vdev.children.first.name(false))
    assert_equal("raidz2-0", pool.root_vdev.children.first.name(true))
    assert_equal(2, pool.root_vdev.children.first.nparity)
    assert_equal(4, pool.root_vdev.children.first.children.count)
    pool.root_vdev.children.first.children.each do |child|
      assert_equal("disk", child.type)
    end
  end

  def test_raidz3
    pool_setup(:raidz3, 1, 5)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal("root", pool.root_vdev.type)
    assert_equal(1, pool.root_vdev.children.count)
    assert_equal("raidz", pool.root_vdev.children.first.type)
    assert_equal("raidz3", pool.root_vdev.children.first.name(false))
    assert_equal("raidz3-0", pool.root_vdev.children.first.name(true))
    assert_equal(3, pool.root_vdev.children.first.nparity)
    assert_equal(5, pool.root_vdev.children.first.children.count)
    pool.root_vdev.children.first.children.each do |child|
      assert_equal("disk", child.type)
    end
  end

  def test_raid10
    pool_setup(:mirror, 2, 2)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal("root", pool.root_vdev.type)
    assert_equal(2, pool.root_vdev.children.count)
    pool.root_vdev.children.each do |ivdev|
      assert_equal("mirror", ivdev.type)
      assert_equal(2, ivdev.children.count)
      ivdev.children.each do |leaf|
        assert_equal("disk", leaf.type)
      end
    end
  end

  def test_raid50
    pool_setup(:raidz1, 2, 3)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal("root", pool.root_vdev.type)
    assert_equal(2, pool.root_vdev.children.count)
    pool.root_vdev.children.each do |ivdev|
      assert_equal("raidz", ivdev.type)
      assert_equal(1, ivdev.nparity)
      assert_equal("raidz1", ivdev.name(false))
      assert_equal(3, ivdev.children.count)
      ivdev.children.each do |leaf|
        assert_equal("disk", leaf.type)
      end
    end
  end

  def test_slogs
    pool_setup(:stripe, 1, 1, 1, 0, 0)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal("root", pool.root_vdev.type)
    assert_equal(2, pool.root_vdev.children.count)
    basic_vdevs = pool.root_vdev.children.select {|c| c.is_log == 0}
    log_vdevs = pool.root_vdev.children.select {|c| c.is_log == 1}
    assert_equal(1, basic_vdevs.size)
    assert_equal(1, log_vdevs.size)
    assert_equal(0, basic_vdevs.first.children.count)
    assert_equal("disk", basic_vdevs.first.type)
    assert_equal(0, log_vdevs.first.children.count)
    assert_equal("disk", log_vdevs.first.type)
  end

  def test_caches
    pool_setup(:stripe, 1, 1, 0, 1, 0)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal("root", pool.root_vdev.type)
    assert_equal(1, pool.root_vdev.children.count)
    assert_equal(1, pool.root_vdev.l2cache.count)
    assert_equal(0, pool.root_vdev.children.first.children.count)
    assert_equal("disk", pool.root_vdev.children.first.type)
    assert_equal(0, pool.root_vdev.l2cache.first.children.count)
    assert_equal("disk", pool.root_vdev.l2cache.first.type)
  end

  def test_spares
    pool_setup(:stripe, 1, 1, 0, 0, 1)
    pool = ZFS::Pool.find_by_name(@poolname)
    assert_equal("root", pool.root_vdev.type)
    assert_equal(1, pool.root_vdev.children.count)
    assert_equal(1, pool.root_vdev.spares.count)
    assert_equal(0, pool.root_vdev.children.first.children.count)
    assert_equal("disk", pool.root_vdev.children.first.type)
    assert_equal(0, pool.root_vdev.spares.first.children.count)
    assert_equal("disk", pool.root_vdev.spares.first.type)
  end
end


class TestScrub < Test::Unit::TestCase
  include ZFSTest

  def setup
    pool_setup
  end

  def teardown
    pool_teardown
  end

  def test_short_scrub
    run_cmd("zpool scrub #{@poolname}")
    retries = 5
    begin
      @pool.refresh
      raise :failed if :finished != @pool.scan_stats[:state]
    rescue
      if retries > 0
        retries -= 1
        sleep 1
        retry
      else
        assert_equal(:finished, @pool.scan_stats[:state])
      end
    end
    assert_equal :scrub, @pool.scan_stats[:func]
  end

end

