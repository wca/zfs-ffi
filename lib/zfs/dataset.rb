#!/usr/bin/env ruby
$LOAD_PATH << File.dirname(File.dirname(__FILE__))
require "zfs/global"
require "zfs/libzfs"
require "zfs/property"
require "zfs/nvlist"
require "thread"

module ZFS
  class Dataset
    # A thread-safe implementation-independent callback lookup mechanism.
    @@cb_data = {}
    @@cb_data_mtx = Mutex.new
    def self.with_callback_data(obj)
      @@cb_data_mtx.synchronize { @@cb_data[obj.object_id] = obj }
      objid = FFI::MemoryPointer.new(:uint64).write_uint64(obj.object_id)
      yield objid
      @@cb_data_mtx.synchronize { @@cb_data.delete(obj.object_id) }
      obj
    end
    def self.get_callback_data(cb_data_id)
      cb_data_id = cb_data_id.read_uint64
      @@cb_data_mtx.synchronize { @@cb_data[cb_data_id] }
    end

    # Class methods.
    class << self
      # What kind of dataset is this class?
      attr_accessor :ds_kind
      # Base properties for this class.
      attr_writer :base_properties
      # ZFS Property callback for this class.  Must be instantiated for the
      # class in order to resolve correctly.
      attr_reader :zfsprop_cb

      def base_properties(cb=false)
        return @base_properties if cb or !@base_properties.empty?
        kind = LibZFS::ZfsType[@ds_kind]
        ZFS.handle # Make sure the handle is initialized.
        LibZFS.zprop_iter_common(@zfsprop_cb, nil, true, true, kind)
        @base_properties
      end
    end

    def self.init(ds_kind)
      @ds_kind, @base_properties = ds_kind, []
      @zfsprop_cb = Proc.new do |prop_id, cb_data_id|
        self.base_properties(true)[prop_id] = LibZFS.zfs_prop_to_name(prop_id)
        LibZFS::ZPROP_CONT # Continue iterating on ZFS properties
      end
      self
    end
    self.init :dataset

    attr_reader :name
    attr_reader :properties
    attr_reader :children
    attr_reader :snapshots

    def initialize(name, handle=nil)
      @name = name
      @properties = {}
      @children, @snapshots = [], []

      handle ||= LibZFS.zfs_open(ZFS.handle, @name,
                                 LibZFS::ZfsType[self.class.ds_kind])
      # NB: There will be another interface for creating a filesystem, so
      #     calling .new for an filesystem that doesn't exist is not supported.
      if handle.null?
        kind_str = self.class.to_s.upcase
        raise NameError, "#{kind_str} '#{name}' not found"
      end
      @handle = handle
      refresh
    end

    def refresh
      enumerate_properties
      enumerate_children
      self
    end

    def method_missing(m, *args, &block)
      @properties.has_key?(m) ? @properties[m] : super
    end

    def inspect
      "#<#{self.class} name=#{@name} properties=#{@properties.inspect}"
    end

    def pretty_print_group(pp)
      pp.breakable
      pp.text "@properties="; pp.pp @properties
    end

    def pretty_print(pp)
      header = sprintf('0x%x', object_id) + ":" + @name.inspect
      pp.group(1, "#<#{self.class}:#{header} ", ">") do
        pretty_print_group(pp)
      end
    end

  protected
    def enumerate_properties
      self.class.base_properties.each_with_index do |prop, prop_id|
        @properties[prop] = get_property(prop_id)
      end

      # User properties are stored as a NVList containing NVPairs which are
      # named using the property name, and have a NVList for the pair's
      # value, which contains two NVPairs, one being the actual value NVPair,
      # and one describing the source of the property.
      @user_props = NVList.from_native(LibZFS.zfs_get_user_props(@handle))
      @user_props.each do |nvp|
        obj = nvp.value.find {|nvp| nvp.name == "value"}
        @properties[nvp.name] = obj.value.value
      end
    end

    def enumerate_children
    end

    def get_property(prop_id)
      name = self.class.base_properties[prop_id]
      raise NameError, "Property #{prop_id} unknown" unless name

      src = FFI::MemoryPointer.new(:uint)
      propbuf = FFI::MemoryPointer.new(:char, LibZFS::ZFS_MAXPROPLEN)
      LibZFS.zfs_prop_get(@handle, prop_id, propbuf, LibZFS::ZFS_MAXPROPLEN,
                          src, nil, 0, true)
      value = propbuf.read_string.force_encoding("UTF-8")
      src = LibZFS::ZpropSource[src.read_uint]
      Property.new(name, value, src)
    end

    ZfsIterFsCallback = Proc.new do |handle, cb_data_id|
      list = ZFS::Dataset.get_callback_data(cb_data_id)
      raise "Callback data not available!" if list.nil?
      list << factory(handle)
      0
    end

    def enumerate(enum_kind)
      ZFS::Dataset.with_callback_data([]) do |objid|
        args = case enum_kind
               when :filesystem then [@handle, ZfsIterFsCallback, objid]
               when :snapshot then [@handle, false, ZfsIterFsCallback, objid]
               else raise ArgumentError, "Enumeration '#{enum_kind}' invalid"
               end
        LibZFS.send("zfs_iter_#{enum_kind}s".to_sym, *args)
      end
    end

  private
    def self.factory(zfs_handle)
      name = LibZFS.zfs_get_name(zfs_handle)
      zfs_type = LibZFS.zfs_get_type(zfs_handle)
      case zfs_type
      when :filesystem then ZFS::FS.new(name, zfs_handle)
      when :snapshot then ZFS::Snapshot.new(name, zfs_handle)
      when :volume then ZFS::Volume.new(name, zfs_handle)
      else raise "ZFS Type #{zfs_type} not supported for #{name}"
      end
    end
  end
end

require "zfs/fs"
require "zfs/snapshot"
require "zfs/volume"
