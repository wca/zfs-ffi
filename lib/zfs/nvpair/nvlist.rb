require 'zfs/nvvalue'
require 'zfs/nvlist'

module NVValue
  class NVList < Base
    def self.c_type; :pointer; end
    def self.from_native(nvp)
      nvl = NVValue.lookup(:nvpair_value_nvlist, nvp).read_pointer
      puts "NVValue::NVList.from_native(#{nvp.inspect})=#{nvl.inspect})"
      ::NVList.from_native(nvl)
    end
    def initialize(nvp=nil, value=nil)
      super
      @value = ::NVList.from_native(value) if value
      self
    end
    def to_native
      @value.to_native
    end
  end
  add_class :nvlist, NVValue::NVList
end
