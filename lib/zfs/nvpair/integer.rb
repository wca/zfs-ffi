require 'zfs/nvvalue'
require 'zfs/nvvalue/array'

module NVValue
  class BaseInteger < Base
    # NB: Bytes are unsigned chars.
    BYTE_BITS = 8 # XXX Use FFI::TYPE_CHAR, but only if it exists.
    VALID_RANGES = {
      :byte   => (0..2**BYTE_BITS-1),
      :uint8  => (0..2**8-1),       :uint16 => (0..2**16-1),
      :uint32 => (0..2**32-1),      :uint64 => (0..2**64-1),
      :int8   => (-2**4..2**4-1),   :int16  => (-2**8..2**8-1),
      :int32  => (-2**16..2**16-1), :int64  => (-2**32..2**32-1)
    }
    def self.c_type
      self.name.split("::").last.downcase.to_sym
    end
    def self.from_native(nvp)
      value = NVValue.lookup("nvpair_value_#{c_type}".to_sym, nvp)
      value = value.method("read_#{c_type}").call
      new(nvp, value)
    end
    def to_native
      ptr = FFI::MemoryPointer.new(self.class.c_type)
      ptr.method("write_#{self.class.c_type}").call(@value)
      ptr
    end
    def validate_change(input)
      unless VALID_RANGES[self.class.c_type].include?(input)
        raise "Value #{input.inspect} invalid for #{self.class}"
      end
    end
  end
  # Dynamically create the integer classes.  Classes that require specific
  # behavior should be defined separately.
  BaseInteger::VALID_RANGES.keys.each do |type|
    klass = NVValue.const_set(type.to_s.capitalize.to_sym,
                              Class.new(NVValue::BaseInteger))
    NVValue.add_class(type, klass)
  end
end
