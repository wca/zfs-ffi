require "zfs/nvvalue"

module NVValue
  class String < Base
    def self.c_type
      :string
    end

    def self.to_value(ptr)
      new(ptr.read_string)
    end

    def self.from_native(nvp)
      to_value(NVValue.lookup(:nvpair_value_string, nvp))
    end

    def to_native
      FFI::MemoryPointer.from_string(@value)
    end
  end

  add_class :string, NVValue::String
end
