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

# Real browser for Stimulus behaviour. Skipped where Chrome is not installed.
class JsSystemTestCase < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]

  def self.chrome_available?
    system("which google-chrome chromium > /dev/null 2>&1") || File.exist?("/Applications/Google Chrome.app")
  end

  setup { skip "Chrome not available" unless self.class.chrome_available? }

  # Signs in through the test-only endpoint from inside the browser, so the
  # session cookie lands in Chrome. Visits a page first to set the origin.
  def sign_in_as(user, from: root_path)
    visit from
    page.evaluate_async_script(<<~JS, test_sign_in_path, user.id)
      const [path, id, done] = arguments
      fetch(path, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: "user_id=" + id }).then(() => done())
    JS
  end
end
