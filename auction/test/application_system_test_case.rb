require "test_helper"

# rack_test needs no browser, so system tests run anywhere (CI, WSL).
# JavaScript behaviour is not exercised here; every control also works as a
# plain form or link. Switch to `driven_by :selenium, using: :headless_chrome`
# to exercise the Stimulus controllers in a real browser.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test

  # Real login (M1). Every fixture user has the password "password123".
  def sign_in_as(user, password: "password123")
    page.driver.post(login_path, email: user.email, password: password)
  end
end
