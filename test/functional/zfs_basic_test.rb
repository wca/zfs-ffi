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
