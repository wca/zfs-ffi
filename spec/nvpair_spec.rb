require File.join(File.dirname(__FILE__), 'spec_helper')

# This gem treats libnvpair as an opaque interface and knows nothing about
# how nvpair objects are created or managed.  It only knows how to call
# methods using opaque pointers.  Therefore, this works by imitating the
# expected behavior of the library interface, and does not try to construct
# actual nvpairs/nvlists/etc.  It does, however, need to read/write C
# pointers, since that's what the gem does.

describe NVPair do
  def common_understanding(nvp_type, value)
    ptr = NVValue.factory(nvp_type, value).to_native
    LibNVPair.should_receive(:nvpair_name).and_return("foo")
    LibNVPair.should_receive(:nvpair_type).and_return(nvp_type)
    LibNVPair.should_receive("nvpair_value_#{nvp_type}".to_sym) do |nvp, valp|
      valp.write_pointer ptr
    end
    NVPair.from_native(nil)
  end
  def should_understand(nvp_type, value)
    nvp = common_understanding(nvp_type, value)
    nvp.nvp_type.should == nvp_type
    nvp.value.value.should == value
  end
  def should_not_understand(nvp_type, value)
    lambda { NVPairSpec.common_understanding(nvp_type, value) }.
      should raise_exception
  end

  it "understands strings" do
    should_understand(:string, "foo")
  end
  it "understands uint64s" do
    should_understand :uint64, 914852
    should_not_understand :uint64, -1
    should_not_understand :uint64, 2**64
  end
  it "understands uint8s" do
    should_understand :uint8, 1
    should_not_understand :uint8, 2**8
  end
  it "understands int16s" do
    should_understand :int16, -123
    should_understand :int16, 124
    should_not_understand :int16, -2**8 - 1
    should_not_understand :int16, 2**8
  end
  it "understands booleans" do
    should_understand(:boolean_value, true)
    should_understand(:boolean_value, false)
  end
end
