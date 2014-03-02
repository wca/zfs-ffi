require 'ffi'

module LibNVPair
  extend FFI::Library
  ffi_lib "nvpair"

  # Add lookup routines for the given nvp_type.  Should be called whenever a
  # value class registers itself via NVValue.add_class.
  def self.add_lookup(nvp_type, array_type)
    attach_function "nvpair_value_#{nvp_type}".to_sym,
      [:pointer, :pointer], :int
    if array_type
      attach_function "nvpair_value_#{array_type}_array".to_sym,
        [:pointer, :pointer, :pointer], :int
    end
  end

  # sys/cddl/contrib/opensolaris/uts/common/sys/nvpair.h:data_type_t: 
  # Must match the order of this enum, so don't use composition.
  #
  # NB: :boolean is an obsolete type; treat it the same as :boolean_value.
  NVPairType = enum(
    :unknown, :boolean, :byte, :int16, :uint16, :int32, :uint32,
    :int64, :uint64, :string, :byte_array, :int16_array, :uint16_array,
    :int32_array, :uint32_array, :int64_array, :uint64_array,
    :string_array, :hrtime, :nvlist, :nvlist_array, :boolean_value,
    :int8, :uint8, :boolean_array, :int8_array, :uint8_array
  )

  # char *nvpair_name(nvpair_t *nvp)
  attach_function :nvpair_name, [:pointer], :string

  # data_type_t nvpair_type(nvpair_t *nvp)
  attach_function :nvpair_type, [:pointer], NVPairType

  # nvpair_t *nvlist_next_nvpair(nvlist_t *nvl, nvpair_t *nvp)
  attach_function :nvlist_next_nvpair, [:pointer, :pointer], :pointer
end
