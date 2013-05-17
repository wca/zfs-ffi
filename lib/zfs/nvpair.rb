require "zfs/libnvpair"

module NVPair
  # Global list of nvpair classes.
  @@klasses = {}
  def self.add_class(nvp_type, klass, opts={})
    array_type = opts[:array_type]
    array_type = nvp_type unless opts.has_key?(:array_type)
    LibNVPair.add_lookup(nvp_type, array_type) unless opts[:no_lookup]
    if array_type
      @@klasses["#{nvp_type}_array".to_sym] = NVPair::Array
    end
    @@klasses[nvp_type] = klass
  end
  def self.get_class(nvp_t)
    @@klasses[nvp_t] or raise ArgumentError, "NVPair type #{nvp_t} unsupported"
  end

  # Lookup routines.
  def self.from_native(nvp)
    nvp_type = LibNVPair.nvpair_type(nvp)
    name = LibNVPair.nvpair_name(nvp).force_encoding("UTF-8")
    puts "NVPair.from_native(#{nvp.inspect}) name=#{name} type=#{nvp_type}"
    get_class(nvp_type).from_native(nvp, name, nvp_type)
  end
  def self.lookup(fcn, nvp)
    ptr = FFI::MemoryPointer.new(:pointer).write_pointer(nil)
    raise "Lookup failed" unless LibNVPair.send(fcn, nvp, ptr).zero?
    ptr
  end
  # Just generate the value from the object given its type.
  def self.to_value(nvp_t, obj)
    get_class(nvp_t).to_value(obj)
  end

  # The base NVPair class.
  class Base
    attr_reader :name
    attr_reader :value
    attr_reader :nvp_type

    def initialize(name, value, nvp_type)
      @name, @value, @nvp_type = name, value, nvp_type
      self
    end
    def value=(new_value)
      validate_change(new_value)
      @value = new_value
    end
    def validate_change(new_value); end

    def inspect
      "#<#{self.class.name} name=#{@name.inspect} value=#{@value.inspect}>"
    end
    def pretty_print(pp)
      header = sprintf('0x%x', object_id) + ":" + @name
      pp.group(1, "#<#{self.class}:#{header} ", ">") do
        pp.breakable
        pp.text "@value="; pp.pp @value
      end
    end
  end
end

Dir["#{File.dirname(__FILE__)}/nvpair/*.rb"].each do |path|
  name = File.basename(path, ".rb")
  require "zfs/nvpair/#{name}"
end
