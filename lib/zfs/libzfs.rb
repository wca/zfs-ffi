require 'ffi'
require 'dl'
require 'dl/import'

# Import libavl.so to workaround broken libzfs.so builds that depend on
# libavl but don't tell the linker.
module LibAVL_DL
  extend DL::Importer
  dlload "libavl.so"
end

# Import libuutil.so too.  See above.
module LibUUtil_DL
  extend DL::Importer
  dlload "libuutil.so"
end

# Generate and manage a singleton object which contains the libzfs handle.
module LibZFS
  extend FFI::Library
  ffi_lib "zfs"

  # sys/cddl/contrib/opensolaris/uts/common/sys/fs/zfs.h
  ZPROP_CONT = -2

  # From cddl/contrib/opensolaris/lib/libzfs/common/libzfs.h
  ZFS_MAXPROPLEN = 4096 # MAXPATHLEN?

  ZfsType = enum(
    :filesystem,    0x1,
    :snapshot,      0x2,
    :volume,        0x4,
    :dataset,       0x1 | 0x2 | 0x4,
    :pool,          0x8,
  )

  ZpropSource = enum(
    :none,          0x1,
    :default,       0x2,
    :temporary,     0x4,
    :local,         0x8,
    :inherited,     0x10,
    :received,      0x20
  )

  ZpoolStatus = enum(
    # Defined in fault.fs.zfs.* namespace with corresponding message IDs.
    :corrupt_cache,
    :missing_device_with_replicas,
    :missing_device_with_no_replicas,
    :corrupt_label_with_replicas,
    :corrupt_label_with_no_replicas,
    :bad_guid_checksum,
    :corrupt_metadata,
    :corrupt_data,
    :failing_device,
    :has_newer_on_disk_version,
    :hostid_mismatch,
    :io_failure_wait_mode,
    :io_failure_continue_mode,
    :bad_log_chain,

    # No message IDs available.
    :faulted_device_with_replicas,
    :faulted_device_with_no_replicas,

    # Not faults per se, but may require administrative attention.
    :has_older_on_disk_version,
    :resilvering,
    :device_offline,
    :device_removed,

    :ok
  )

  # libzfs_handle_t *libzfs_init()
  attach_function :libzfs_init, [], :pointer

  # void libzfs_fini(libzfs_handle_t*)
  attach_function :libzfs_fini, [:pointer], :void

  # const char *zpool_get_name(zpool_handle_t*)
  attach_function :zpool_get_name, [:pointer], :string

  # int (*zpool_iter_cb)(zpool_handle_t *, void *cb_data)
  callback :zpool_iter_cb, [:pointer, :pointer], :int

  # int zpool_iter(libzfs_handle_t*, zpool_iter_cb*, void *)
  attach_function :zpool_iter, [:pointer, :zpool_iter_cb, :pointer], :int

  # int zpool_get_prop(zpool_handle_t *zhp, zpool_prop_t prop, char *buf,
  #                    size_t len, zprop_source_t *srctype)
  attach_function :zpool_get_prop,
    [:pointer, :uint, :pointer, :uint, :pointer], :int

  # int (*zprop_iter_cb)(int prop, void *cb_data)
  callback :zprop_iter_cb, [:int, :pointer], :int

  # int zprop_iter_common(zprop_func func, void *cb, boolean_t show_all,
  #                       boolean_t ordered, zfs_type_t type)
  attach_function :zprop_iter_common,
    [:zprop_iter_cb, :pointer, :bool, :bool, ZfsType], :int

  # const char *zpool_prop_to_name(zpool_prop_t prop)
  attach_function :zpool_prop_to_name, [:int], :string

  # nvlist_t zpool_get_config(zpool_handle_t *zhp, nvlist_t **oldconfig)
  attach_function :zpool_get_config, [:pointer, :pointer], :pointer

  # zpool_status_t zpool_get_status(zpool_handle_t *zhp, char **msgid)
  attach_function :zpool_get_status, [:pointer, :pointer], ZpoolStatus

  # char *zpool_vdev_name(libzfs_handle_t*, zpool_handle_t *, nvlist_t*, boolean_t)
  attach_function :zpool_vdev_name, [:pointer, :pointer, :pointer, :bool], :string

  # const char *zfs_prop_to_name(zfs_prop_t prop)
  attach_function :zfs_prop_to_name, [:int], :string

  # zfs_handle_t *zfs_open(libzfs_handle_t *hdl, const char *path, int types)
  attach_function :zfs_open, [:pointer, :string, :int], :pointer

  # int zfs_validate_name(libzfs_handle_t *hdl, const char *path, int type,
  #                       boolean_t modifying)
  attach_function :zfs_validate_name, [:pointer, :string, :int, :bool], :int

  # const char *libzfs_error_description(libzfs_handle_t *hdl)
  attach_function :libzfs_error_description, [:pointer], :string

  # int zfs_prop_get(zfs_handle_t *zhp, zfs_prop_t prop, char *propbuf,
  #                  size_t proplen, zprop_source_t *src, char *statbuf,
  #                  size_t statlen, boolean_t literal)
  attach_function :zfs_prop_get,
    [:pointer, :int, :pointer, :uint, :pointer, :pointer, :uint, :bool],
    :int

  # nvlist_t *zfs_get_user_props(zfs_handle_t *zhp)
  attach_function :zfs_get_user_props, [:pointer], :pointer

  # typedef int (*zfs_iter_f)(zfs_handle_t *, void *);
  callback :zfs_iter_cb, [:pointer, :pointer], :int

  # int zfs_iter_filesystems(zfs_handle_t *zhp, zfs_iter_f func, void *data)
  attach_function :zfs_iter_filesystems,
    [:pointer, :zfs_iter_cb, :pointer], :int

  # int zfs_iter_snapshots(zfs_handle_t *zhp, boolean_t simple,
  #                        zfs_iter_f func, void *data)
  attach_function :zfs_iter_snapshots,
    [:pointer, :bool, :zfs_iter_cb, :pointer], :int

  # zfs_type_t zfs_get_type(const zfs_handle_t *zhp)
  attach_function :zfs_get_type, [:pointer], ZfsType

  # const char *zfs_get_name(const zfs_handle_t *zhp)
  attach_function :zfs_get_name, [:pointer], :string
end
