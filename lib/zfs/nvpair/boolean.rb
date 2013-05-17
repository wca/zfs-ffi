require 'zfs/nvvalue'

module NVValue
  class Boolean < Base
    def self.c_type; :int; end
    def self.from_native(nvp)
      value = NVValue.lookup(:nvpair_value_boolean_value, nvp).read_uint
      raise "Value #{value.inspect} not a boolean" unless [0, 1].include?(value)
      new(nvp, value == 1)
    end
    def to_native
      FFI::MemoryPointer.new(self.class.c_type).write_int(@value ? 1 : 0)
    end
  end
  add_class :boolean, NVValue::Boolean, :no_lookup => true
  add_class :boolean_value, NVValue::Boolean, :array_type => :boolean
end
