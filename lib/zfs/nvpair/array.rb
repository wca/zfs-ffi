require 'zfs/nvpair'

module NVPair
  class Array < Base
    include Enumerable

    attr_reader :element_type

    def initialize(name, value, nvp_type, element_type)
      @element_type = element_type
      super(name, value, nvp_type)
    end
    def each(&block)
      @value.each(&block)
    end
    def self.from_native(nvp, name, nvp_type)
      arr = FFI::MemoryPointer.new(:pointer).write_pointer(nil)
      num = FFI::MemoryPointer.new(:uint).write_uint(0)
      lookup_fcn = "nvpair_value_#{nvp_type}".to_sym
      LibNVPair.send(lookup_fcn, nvp, arr, num)

      element_type = nvp_type.to_s.sub(/_array$/, "").to_sym
      element_c_type = NVPair.get_class(element_type).c_type
      read_method = "read_array_of_#{element_c_type}".to_sym
      num = num.read_uint
      return [] if num.zero? or arr.null?
      arr = arr.read_pointer
      puts "NVPair::Array.from_native(#{nvp.inspect}) num=#{num} arr=#{arr.inspect} read_method=#{read_method}"

      value = arr.method(read_method).call(num).collect do |obj|
        puts "obj=#{obj.inspect}"
        NVPair.to_value(element_type, obj)
      end
      new(name, value, nvp_type, element_type)
    end
  end
end
