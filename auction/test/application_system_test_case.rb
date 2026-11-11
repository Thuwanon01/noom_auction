require "test_helper"

# rack_test needs no browser, so system tests run anywhere (CI, WSL).
# JavaScript behaviour (debounce, Turbo Frame swaps) is not exercised here;
# every control also works as a plain GET form or link.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test

  def sign_in_as(user)
    page.driver.post(test_sign_in_path, user_id: user.id)
  end
end
