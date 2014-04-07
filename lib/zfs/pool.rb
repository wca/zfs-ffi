require "zfs/fs"
require "zfs/device"

module ZFS
  class Pool
    extend Enumerable
    @@blocks = {}

    attr_reader :handle
    attr_reader :name
    attr_reader :properties
    attr_reader :root_vdev
    attr_reader :root_zfs
    attr_reader :spares
    attr_reader :caches
    attr_reader :slogs
    attr_reader :status
    attr_reader :status_reason

    ZpoolIterCallback = Proc.new do |handle, object_id|
      objid = object_id.read_ulong
      block = @@blocks[objid]
      raise RuntimeError, "No object #{object_id} in @@blocks!" unless block
      name = LibZFS.zpool_get_name(handle)
      block.call(new(name, handle))
      0
    end

    ZpoolPropBaseCallback = Proc.new do |prop_id, cb_data|
      @@base_properties[prop_id] = LibZFS.zpool_prop_to_name(prop_id)
      LibZFS::ZPROP_CONT # Continue iterating on zpool properties
    end

    def self.base_properties
      return @@base_properties if defined?(@@base_properties)
      @@base_properties = []
      LibZFS.zprop_iter_common(ZpoolPropBaseCallback, nil, true, true, :pool)
      @@base_properties
    end

    def self.each(&block)
      @@blocks[block.object_id] = block
      objid = FFI::MemoryPointer.new(:uint64).write_uint64(block.object_id)
      LibZFS.zpool_iter(ZFS.handle, ZpoolIterCallback, objid)
      @@blocks.delete(block.object_id)
      []
    end

    def self.find_by_name(name)
      find {|p| p.name == name}
    end

    # XXX: Do not instantiate this class by hand!  Pools may only be created by
    # find_by_name.  We segfault otherwise due to uninitialized data within the
    # libzfs handle. 
    private_class_method :new
    def initialize(name, handle)
      @name = name
      @handle = handle
      @root_zfs = FS.new @name
      @properties = {}
      @root_vdev = nil
      @spares, @caches, @slogs = [], [], []
      refresh
      self
    end

    def get_property(prop_id)
      src = FFI::MemoryPointer.new(:uint)
      buf = FFI::MemoryPointer.new(:char, LibZFS::ZFS_MAXPROPLEN)
      # NB: There is no way, in libzfs, to get the untranslated number
      #     values for zpool properties, unlike zfs properties.
      LibZFS.zpool_get_prop(@handle, prop_id, buf, LibZFS::ZFS_MAXPROPLEN, src)
      name = @@base_properties[prop_id]
      value = buf.read_string
      src = LibZFS::ZpropSource[src.read_uint]
      Property.new(name, value, src)
    end

    def refresh_config
      @root_vdev = ZFS::Device.new(self, LibZFS.zpool_get_config(@handle, nil), true)
      #@vdev_stats = @vdev_tree["vdev_stats"]
      #@health = zpool_state_to_name(vs->vs_state, vs->vs_aux);
    end

    def refresh_status
      ptr = FFI::MemoryPointer.new(:pointer, 1).write_pointer(nil)
      @status = LibZFS.zpool_get_status(@handle, ptr)
      strptr = ptr.read_pointer unless ptr.null?
      @status_reason = strptr.read_string unless strptr.null?
    end

    # Refresh the pool properties and child lists.
    def refresh
      self.class.base_properties.each_with_index do |prop, prop_id|
        @properties[prop] = get_property(prop_id)
      end
      refresh_status
      refresh_config
      self
    end

    def self.cmd_proc(args)
      require 'pp'
      each {|pool| pp pool}
      0
    end
  end
end
