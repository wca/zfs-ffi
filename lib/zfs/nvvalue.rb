require "zfs/libnvpair"

module NVValue

  # Global list of value classes.
  @@nvvalues = {}
  def self.add_class(nvp_type, klass, opts={})
    array_type = opts[:array_type]
    array_type = nvp_type unless opts.has_key?(:array_type)
    LibNVPair.add_lookup(nvp_type, array_type) unless opts[:no_lookup]
    if array_type
      @@nvvalues["#{nvp_type}_array".to_sym] = NVValue::Array
    end
    @@nvvalues[nvp_type] = klass
  end

  def self.get_class(nvp_type)
    @@nvvalues[nvp_type]
  end

  # Global factory.
  def self.get_klass(nvp_type)
    @@nvvalues[nvp_type] or
      raise ArgumentError, "nvp_type #{nvp_type} not supported"
  end

  def self.factory(nvp_type, value, nvp=nil)
    get_klass(nvp_type).new(value)
  end

  def self.from_native(nvp, nvp_type)
    get_klass(nvp_type).from_native(nvp)
  end

  def self.lookup(fcn, nvp)
    ptr = FFI::MemoryPointer.new(:pointer).write_pointer(nil)
    ret = LibNVPair.send(fcn, nvp, ptr)
    unless ret.zero? && !ptr.null?
      # XXX Fix this to raise an Errno exception.
      raise "Lookup failed with error code #{ret}"
    end
    ptr
  end

  # Convert a raw pointer to an object of this type.
  def self.to_value(nvp_type, obj)
    get_class(nvp_type).to_value(obj)
  end

  class Base
    def initialize(value=nil)
      # Invoke the validation mechanism on initialization, too.
      self.value = value
      self
    end

    def value
      @value
    end

    def value=(new_value)
      validate_change(new_value)
      @value = new_value
    end

    def validate_change(input)
    end

    def pretty_print(pp)
      pp.group(1, "#<#{self.class}:#{sprintf('0x%x', object_id)} ", ">") do
        pp.breakable
        pp.text "@value="; pp.pp @value
      end
    end

  end
end

# We must import array before any other files, because NVValue::Array is used
# by NVValue.add_class
require "zfs/nvvalue/array"
Dir["#{File.dirname(__FILE__)}/nvvalue/*.rb"].each do |path|
  name = File.basename(path, ".rb")
  next if name == "array"
  require "zfs/nvvalue/#{name}"
end
