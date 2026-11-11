require "test_helper"

# rack_test needs no browser, so system tests run anywhere (CI, WSL).
# JavaScript behaviour (debounce, Turbo Frame swaps) is not exercised here;
# every control also works as a plain GET form or link.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test

  def sign_in_as(user)
    page.driver.post(test_sign_in_path, user_id: user.id)
  end

  # turbo-rails makes #visit wait until every <turbo-cable-stream-source>
  # is connected. rack_test runs no JavaScript, so they never connect; only
  # wait in a real browser.
  def connect_turbo_cable_stream_sources(...)
    super unless Capybara.current_driver == :rack_test
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
