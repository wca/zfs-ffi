require 'test/unit'
# required for class/module-level stubs.
require 'mocha/setup'

require 'zfs'

class Object
  def metaclass
    class << self
      self
    end
  end
end
