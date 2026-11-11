require "test_helper"

class MaskingHelperTest < ActionView::TestCase
  test "masks a national ID like the spec" do
    assert_equal "1-2345-XXXXX-XX-1", mask_national_id("1234567890121")
  end

  test "masks a phone like the spec" do
    assert_equal "08X-XXX-1234", mask_phone("0812341234")
  end

  test "returns blank for malformed input instead of leaking it" do
    assert_equal "", mask_national_id("123")
    assert_equal "", mask_phone(nil)
  end
end
