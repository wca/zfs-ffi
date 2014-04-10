require 'test_helper'

class TestNVPair < Test::Unit::TestCase
  def setup
    LibNVPair.expects(:nvpair_name).at_least_once.with(nil).returns("foo")
  end

  # Requires knowledge from the test, so must be called from them.
  def common(nvp_type, value)
    nvvalue_m = "nvpair_value_#{nvp_type}".to_sym
    ptr = NVValue.factory(nvp_type, value).to_native
    LibNVPair.expects(:nvpair_type).with(nil).returns(nvp_type)
    LibNVPair.instance_eval do
      metaclass.send(:define_method, nvvalue_m) do |nvp, valp|
        case nvp_type
        when :boolean_value
          fcn = "uint"
        when :string
          fcn = "pointer"
        else
          fcn = nvp_type
        end
        valp.send("write_#{fcn}".to_sym, ptr.send("read_#{fcn}".to_sym))
        0 # All of these functions return 0 on success, errno otherwise
      end
    end
    NVPair.from_native(nil)
  end

  def should_understand(nvp_type, value)
    nvp = common(nvp_type, value)
    assert_equal(nvp_type, nvp.nvp_type,
                 "Generated nvpair object should think it is a #{nvp_type}")
    assert_equal(value, nvp.value.value,
                 "Generated nvpair object should think its value is #{value}")
  end

  def should_not_understand(nvp_type, value)
    assert_raises(ArgumentError) { common(nvp_type, value) }
  end

  def test_strings
    should_understand(:string, "foo")
  end

  def test_uint64s
    should_understand(:uint64, 914852)
    should_not_understand(:uint64, -1)
    should_not_understand(:uint64, 2**64)
  end

  def test_uint8s
    should_understand(:uint8, 1)
    should_not_understand(:uint8, 2**8)
  end

  def test_int16s
    should_understand(:int16, -123)
    should_understand(:int16, 124)
    should_not_understand(:int16, -2**8 - 1)
    should_not_understand(:int16, 2**8)
  end

  def test_booleans
    should_understand(:boolean_value, true)
    should_understand(:boolean_value, false)
  end
end
