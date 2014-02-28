require 'zfs/nvvalue/integer'
require 'zfs/nvvalue'

module NVValue
  class Hrtime < BaseInteger
    def self.c_type; :uint64; end
    def self.from_native(nvp)
      new(Time.at(NVValue.lookup(:nvpair_value_hrtime, nvp).read_uint64), nvp)
    end
    def value=(input)
      # Allow Time objects to be assigned too.
      input = input.to_i if input.is_a? Time
      super(input)
    end
  end
  add_class :hrtime, NVValue::Hrtime, :array_type => nil
end
