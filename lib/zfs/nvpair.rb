require "zfs/libnvpair"
require "zfs/nvvalue"

class NVPair
  # Generate an NVPair from a native object.
  def self.from_native(nvp)
    nvp_type = LibNVPair.nvpair_type(nvp)
    name = LibNVPair.nvpair_name(nvp).force_encoding("UTF-8")
    nvv = NVValue.get_class(nvp_type).from_native(nvp)
    new(name, nvv, nvp_type)
  end

  attr_reader :name
  attr_reader :value
  attr_reader :nvp_type

  def initialize(name, value, nvp_type)
    unless (value.is_a?(NVValue::Base) || value.is_a?(NVList))
      raise ArgumentError, "Value argument must be a NVValue or NVList"
    end
    @name, @value, @nvp_type = name, value, nvp_type
    self
  end

  def value=(new_value)
    @value.value = new_value
  end

  def inspect
    "#<#{self.class.name} name=#{@name.inspect} value=#{@value.inspect}>"
  end

  def pretty_print(pp)
    header = sprintf('0x%x', object_id) + ":" + @name
    pp.group(1, "#<#{self.class}:#{header} ", ">") do
      pp.breakable
      pp.text "@value="; pp.pp @value
    end
  end
end
