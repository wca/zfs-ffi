require 'test_helper'

class TestBasic < Test::Unit::TestCase
  include ZFSTest

  def setup
    pool_setup
  end

  def teardown
    pool_teardown
  end

  def test_zfs_pool_lookup_works
    assert_not_nil(ZFS::Pool.find_by_name(@poolname))
  end
end
