require "zfs/global"
require "zfs/libzfs"
require "zfs/property"
require "zfs/nvlist"
require "zfs/dataset"

module ZFS
  class FS < Dataset
    self.init :filesystem

    def inspect
      "#<#{self.class} name=#{@name.inspect}>"
    end

    def pretty_print_group(pp)
      super
      pp.text ","; pp.breakable
      pp.text "@children="; pp.pp @children
      pp.text ","; pp.breakable
      pp.text "@snapshots="; pp.pp @snapshots
    end

  protected
    def enumerate_children
      @children = enumerate(:filesystem)
      @snapshots = enumerate(:snapshot)
    end
  end
end
