require "zfs/nvvalue"

module ZFS
  class Device
    attr_reader :pool
    attr_reader :config_nvl

    # Create a new ZFS::Device.  The parameters are arcane in order to reduce
    # the number of conversions of nvlists between C and Ruby format, since
    # such conversions are slow.
    #
    # pool  [ZFS::Pool] Backpointer to this device's pool
    # config_nvl_native [nvlist_t*] Native format pointer to either the pool's
    #                               nvlist or this device's nvlist.
    # isroot  [Boolean]             If true, then this is a root vdev and
    #                               config_nvl_native refers to the pool's
    #                               nvlist.  If false, then this is not a root
    #                               vdev and config_nvl_native refers to the
    #                               device's nvlist.
    def initialize(pool, config_nvl_native, root=false)
      @pool, @config_nvl_native = pool, config_nvl_native
      if root
        @config_nvl = NVList.from_native(config_nvl_native)["vdev_tree"].value
      else
        @config_nvl = NVList.from_native(config_nvl_native)
      end
    end

    def children
      return to_enum(:children) unless block_given?
      return if @config_nvl["children"].nil?

      @config_nvl["children"].value.each do |nvl|
        yield Device.new(@pool, nvl.value)
      end
    end

    def method_missing(meth, *args, &block)
      key = meth.to_s
      return @config_nvl[key].value.value if @config_nvl.has_key?(key)
      super
    end

    def name(verbose=false)
      LibZFS.zpool_vdev_name(ZFS.handle, @pool.handle, @config_nvl_native, verbose)
    end
  end
end
