#!/usr/bin/env ruby
require "zfs/global"
require "zfs/libzfs"
require "zfs/property"
require "zfs/nvlist"
require "zfs/dataset"

module ZFS
  class Snapshot < Dataset
    self.init :snapshot
    # XXX: Need to add the following features:
    # - Enumerate recursive snapshots as children of this one.
    # - Link to older/newer snapshots of the parent.
  end
end
