require "test_helper"

# Real headless Chrome, for the JavaScript of the product wizard (uploads, auction setup).
# Opt-in: run with BROWSER_TESTS=1 bin/rails test:system (needs Chrome). Skipped otherwise because the browser
# login step is still flaky (about 1 run in 3 stays on /login); see the M2.9 PR.
class BrowserSystemTestCase < ActionDispatch::SystemTestCase
  CHROME_PATHS = [ "/Applications/Google Chrome.app", "/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser" ].freeze

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  setup do
    skip "Set BROWSER_TESTS=1 to run the Chrome tests" unless ENV["BROWSER_TESTS"]
    skip "Chrome is not installed" unless CHROME_PATHS.any? { |path| File.exist?(path) }
  end

  # Real login through the form (password of every fixture user is "password123").
  def browser_sign_in(user)
    visit login_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Login"
    # Wait for the redirect to finish; visiting another page too early cancels the login.
    using_wait_time(8) { assert_no_current_path login_path }
  end
end
