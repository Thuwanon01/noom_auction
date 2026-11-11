require "test_helper"

# System tests use rack_test (no browser needed). The onboarding pages work
# without JavaScript, so this covers the full flow. Tests that need the Stimulus
# controllers use BrowserSystemTestCase instead.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test

  # Real login (every fixture user has the password "password123").
  def sign_in_as(user, password: "password123")
    page.driver.post(login_path, email: user.email, password: password)
  end
end
