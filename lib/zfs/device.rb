require "zfs/nvvalue"

module ZFS
  class Device
    attr_reader :pool
    attr_reader :config_nvl

    def initialize(pool, config_nvl)
      @pool, @config_nvl = pool, config_nvl
    end

    def children
      return to_enum(:children) unless block_given?
      return if @config_nvl["children"].nil?

      @config_nvl["children"].value.each do |nvl|
        yield Device.new(@pool, NVList.from_native(nvl.value))
      end
    end

    def method_missing(meth, *args, &block)
      key = meth.to_s
      return @config_nvl[key].value.value if @config_nvl.has_key?(key)
      super
    end
  end
end
