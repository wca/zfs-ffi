require "zfs/nvpair"

# NVList behaves like Hash, but should not be treated exactly like one.
# It is necessary to preserve additional attributes about pairings that
# would not be feasible with Hash.
#
# Most of the logic for parsing nvlists is actually in NVPair & NVValue.
# The only thing we try to do here is iterate on the nvlist.
#
# Note that there is also a NVValue::NVList, which is how we support nvlists
# that are themselves values of a nvpair.
class NVList
  include Enumerable

  def self.from_native(nvl)
    obj = self.new
    nvp = nil
    loop do
      nvp = LibNVPair.nvlist_next_nvpair(nvl, nvp)
      break if nvp.null?
      nvpair = NVPair.from_native(nvp)
      obj[nvpair.name] = nvpair
    end
    obj
  end
  def initialize
    @nvpairs = {}
    self
  end
  def keys; @nvpairs.keys; end
  def values; @nvpairs.values; end
  def each(&block); @nvpairs.values.each(&block); end
  def inspect
    "#<#{self.class.name} pairs=#{@nvpairs.values.inspect}>"
  end
  def pretty_print(pp)
    pp.group(1, "#<#{self.class}:#{sprintf('0x%x', object_id)} ", ">") do
      pp.breakable
      pp.text "@nvpairs="; pp.pp @nvpairs.values
    end
  end
  def [](name)
    @nvpairs[name]
  end
  def []=(name, value)
    @nvpairs[name] = value
  end
end
