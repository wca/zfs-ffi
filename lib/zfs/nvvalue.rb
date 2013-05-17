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
  def self.get_class(nvp_type); @@nvvalues[nvp_type]; end

  # Global factory.
  def self.get_klass(nvp_type)
    @@nvvalues[nvp_type] or
      raise ArgumentError, "nvp_type #{nvp_type} not supported"
  end
  def self.factory(nvp_type, value, nvp=nil)
    get_klass(nvp_type).new(nil, value)
  end
  def self.from_native(nvp, nvp_type)
    puts "NVValue.from_native(#{nvp.inspect}, #{nvp_type})"
    get_klass(nvp_type).from_native(nvp)
  end
  def self.lookup(fcn, nvp)
    ptr = FFI::MemoryPointer.new(:pointer).write_pointer(nil)
    raise "Lookup failed" unless LibNVPair.send(fcn, nvp, ptr).zero?
    ptr
  end

  class Base
    def initialize(nvp=nil, value=nil)
      @nvp = nvp
      puts "#{self.class.name}.initialize(#{nvp.inspect}, #{value.inspect})"
      self.value = value
      self
    end
    def value; @value; end
    def value=(new_value)
      validate_change(new_value)
      @value = new_value
    end
    def validate_change(input); end
    def pretty_print(pp)
      pp.group(1, "#<#{self.class}:#{sprintf('0x%x', object_id)} ", ">") do
        pp.breakable
        pp.text "@value="; pp.pp @value
      end
    end
  end
end

Dir["#{File.dirname(__FILE__)}/nvvalue/*.rb"].each do |path|
  name = File.basename(path, ".rb")
  require "zfs/nvvalue/#{name}"
end
