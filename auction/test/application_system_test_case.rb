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

  # Importmap loads controller modules asynchronously (eagerLoadControllersFrom
  # imports each one with a promise), so window.Stimulus exists before e.g.
  # buy-now is registered. Interacting before then silently skips the
  # controller (a Buy now click submits without the confirm dialog). Wait
  # until every controller named on the page is connected.
  STIMULUS_READY_JS = <<~JS.freeze
    (() => {
      const app = window.Stimulus
      if (!app) return false
      return [ ...document.querySelectorAll("[data-controller]") ].every((el) =>
        el.getAttribute("data-controller").split(/\s+/).filter(Boolean)
          .every((id) => app.getControllerForElementAndIdentifier(el, id)))
    })()
  JS

  def visit(...)
    super.tap { wait_for_stimulus }
  end

  def wait_for_stimulus(timeout: 10)
    deadline = Time.now + timeout
    until page.evaluate_script(STIMULUS_READY_JS)
      flunk "Stimulus controllers did not connect" if Time.now > deadline
      sleep 0.05
    end
  end

  # Clicks are dispatched with element.click() in the page. Evidence from
  # debugging (event listeners installed via CDP before page scripts ran):
  # in ~1 of 3 runs chromedriver reported a native click as done while no
  # click event reached the document at all, so the Stimulus handler under
  # test never ran. element.click() still goes through the real event path
  # (click -> form submit -> Stimulus action -> Turbo); only the pointer
  # simulation is skipped. Clicking itself is not what these tests check.
  def click_button(locator = nil, **options)
    button = find_button(locator, **options)
    page.execute_script("arguments[0].click()", button)
    button
  end

  # Real login form (M1); the test-only sign-in endpoint is gone. Values are
  # set with JS for the same reason as click_button above; typing into the
  # login form is covered by M1's own tests.
  def sign_in_as(user, password: "password123")
    visit login_path
    page.execute_script(<<~JS, user.email, password)
      const [email, password] = arguments
      document.querySelector("input[name=email]").value = email
      document.querySelector("input[name=password]").value = password
      document.querySelector("form[action='/login']").requestSubmit()
    JS
    assert_no_current_path login_path, wait: 10
  end
end
