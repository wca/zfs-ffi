require 'zfs/nvvalue'

module NVValue
  class Boolean < Base
    def self.c_type; :int; end
    def self.to_value(ptr)
      uint_val = ptr.read_uint
      raise "Value #{uint_val} not boolean" unless [0, 1].include?(uint_val)
      new(uint_val == 1)
    end
    def self.from_native(nvp)
      to_value(NVValue.lookup(:nvpair_value_boolean_value, nvp))
    end
    def to_native
      FFI::MemoryPointer.new(self.class.c_type).write_int(@value ? 1 : 0)
    end
  end
  add_class :boolean, NVValue::Boolean, :no_lookup => true
  add_class :boolean_value, NVValue::Boolean, :array_type => :boolean
end
