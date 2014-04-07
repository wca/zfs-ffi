require "zfs/libzfs"

module ZFS
  class Handle
    @@handle = nil

    def self.open
      @@handle ||= LibZFS.libzfs_init
    end

    def self.close
      LibZFS.libzfs_fini(@@handle) unless @@handle.nil?
      @@handle = nil
    end
  end

  # Global ZFS methods.
  def self.handle
    Handle.open
  end

  def self.reopen
    Handle.close
    Handle.open
  end

  def self.last_error
    LibZFS.libzfs_error_description(handle)
  end

  # NB: Opening a ZFS will validate its name too.
  def self.validate_name(name, types=LibZFS::ZfsType[:dataset])
    if LibZFS.zfs_validate_name(handle, name, types, false).zero?
      raise ZFS.last_error
    end
  end
end
