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
      ptr = NVValue.lookup(:nvpair_value_string, nvp).read_pointer
      to_value(ptr)
    end

    # String NVs are technically 'const char **', so to convert to the
    # native form, we must create two pointers, one to point to the other,
    # which itself points to the string value.
    def to_native
      ptr = FFI::MemoryPointer.new(:pointer, 1)
      ptr.write_pointer(FFI::MemoryPointer.from_string(@value))
      ptr
    end
  end

  add_class :string, NVValue::String
end
