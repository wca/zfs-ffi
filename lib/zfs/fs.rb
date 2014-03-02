#!/usr/bin/env ruby
$LOAD_PATH << File.dirname(File.dirname(__FILE__))
require "zfs/global"
require "zfs/libzfs"
require "zfs/property"
require "zfs/nvlist"
require "zfs/dataset"

module ZFS
  class FS < Dataset
    self.init :filesystem

    def inspect
      "#<#{self.class} name=#{@name} properties=#{@properties.inspect} " +
        "children=#{@children.inspect} snapshots=#{@snapshots.inspect}>"
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

    def self.cmd_proc(args)
      puts "Listing filesystems: args=#{args.inspect}"
      require 'pp'
      args.each {|name| pp Hash[name, ZFS::FS.new(name)]}
      0
    end
  end
end

exit(ZFS::FS.cmd_proc(ARGV)) if $0 == __FILE__
