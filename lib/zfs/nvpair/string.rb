require "zfs/nvvalue"

module NVValue
  class String < Base
    def self.c_type; :string; end
    def self.from_native(nvp)
      new(nvp, NVValue.lookup(:nvpair_value_string, nvp).read_pointer.read_string)
    end
    def to_native
      FFI::MemoryPointer.from_string(@value)
    end
  end
  add_class :string, NVValue::String
end
