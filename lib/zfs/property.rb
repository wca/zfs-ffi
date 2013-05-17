module ZFS
  class Property
    attr_reader :name
    attr_reader :value
    attr_reader :source

    def initialize(name, value, source=:default)
      @name, @source = name, source
      # Convert value to an integer if possible.
      is_int = Integer(value) rescue false
      @value = is_int ? value.to_i : value
      self
    end
    def to_s; @value.inspect; end
    #def pretty_print(pp)
    #end
  end
end
