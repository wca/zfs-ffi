#!/usr/bin/env ruby
require "zfs/global"
require "zfs/libzfs"
require "zfs/property"
require "zfs/nvlist"
require "zfs/dataset"

module ZFS
  class Volume < Dataset
    self.init :volume
  end
end
