$LOAD_PATH.unshift "#{File.dirname(File.dirname(__FILE__))}/lib"

require 'rspec'

module ZfsSpec
  def self.randstr(length=12)
    rand(36**length).to_s(36)
  end
end

# Stub FFI, to avoid dependencies on the libraries used.
require 'ffi'
module FFI
  module Library
    def ffi_lib(*args)
    end
    def attach_function(*args)
    end
  end
end

require 'zfs'
