require 'zfs/nvvalue/array'
require 'zfs/nvvalue'
require 'zfs/nvlist'

module NVValue
  class NVList < Base
    def self.c_type; :pointer; end
    def self.to_value(ptr)
      ::NVList.from_native(ptr)
    end
    def self.from_native(nvp)
      # In the case of NVList, nvpair_value_nvlist() treats the pointer we
      # provide as a nvlist_t **, so we must reference the pointer again here.
      to_value(NVValue.lookup(:nvpair_value_nvlist, nvp).read_pointer)
    end
    def to_native
      @value.to_native
    end
  end
  add_class :nvlist, NVValue::NVList
end
