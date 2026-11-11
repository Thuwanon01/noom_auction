require "test_helper"

class UserDisplayNameTest < ActiveSupport::TestCase
  test "uses the name when there is one" do
    assert_equal "Somchai", User.new(name: "Somchai", email: "x@example.com").display_name
  end

  test "falls back to the part of the email before the @" do
    assert_equal "done", users(:completed).display_name
    assert_equal "pat", User.new(name: "  ", email: "pat@example.com").display_name
  end

  test "admin defaults to false and name is optional" do
    user = User.new(email: "new@example.com", password: "password123")
    assert_not user.admin?
    assert user.valid?
  end

  test "name is limited to 100 characters" do
    assert_not User.new(email: "a@example.com", password: "password123", name: "x" * 101).valid?
  end
end
