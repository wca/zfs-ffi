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



