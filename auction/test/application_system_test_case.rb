require "test_helper"

# System tests use rack_test (no browser needed). The onboarding pages work
# without JavaScript, so this covers the full flow. Switch to
# `driven_by :selenium, using: :headless_chrome` to exercise the Stimulus
# controllers in a real browser.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test
end
