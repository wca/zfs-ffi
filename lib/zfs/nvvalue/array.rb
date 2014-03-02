require 'zfs/nvpair'

module NVValue
  class Array < Base
    include Enumerable

    attr_reader :element_type

    def each(&block)
      @value.each(&block)
    end

    def self.from_native(nvp)
      # The nvpair type is known by the caller, but this is the only NVValue
      # that doesn't already know what it is.  Just bite the bullet and call
      # nvpair_type on nvp again.
      nvp_type = LibNVPair.nvpair_type(nvp)
      arr = FFI::MemoryPointer.new(:pointer).write_pointer(nil)
      num = FFI::MemoryPointer.new(:uint).write_uint(0)
      lookup_fcn = "nvpair_value_#{nvp_type}".to_sym
      LibNVPair.send(lookup_fcn, nvp, arr, num)

      if arr.null?
        # XXX: Put errno in this exception message too.
        raise "Error reading array of #{nvp_type}"
      end

      element_type = nvp_type.to_s.sub(/_array$/, "").to_sym
      element_c_type = NVValue.get_class(element_type).c_type
      read_method = "read_array_of_#{element_c_type}".to_sym
      num = num.read_uint
      arr = arr.read_pointer

      value = arr.method(read_method).call(num).collect do |obj|
        # Here, 'obj' is a direct read of the value, so just pass it directly.
        NVValue.get_class(element_type).new(obj)
      end
      obj = new(value)
      obj.instance_variable_set(:@element_type, element_type)
      obj
    end
  end
end
