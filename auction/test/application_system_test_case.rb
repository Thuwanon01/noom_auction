require "test_helper"

# System tests use rack_test (no browser needed). The onboarding pages work
# without JavaScript, so this covers the full flow. Tests that need the Stimulus
# controllers use BrowserSystemTestCase instead.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test
end
