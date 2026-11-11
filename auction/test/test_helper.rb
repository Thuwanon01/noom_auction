ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Temporarily replace a singleton method, e.g. to force CreditScoring to fail.
    # Safe with process-based parallel tests.
    def with_stubbed(object, method_name, implementation)
      original = object.method(method_name)
      object.define_singleton_method(method_name, &implementation)
      yield
    ensure
      object.define_singleton_method(method_name, original)
    end
  end
end

module SignInHelper
  # M2 tests were written with this name; it is the real login now.
  def login_as(user) = sign_in_as(user)

  # Every fixture user has the password "password123".
  def sign_in_as(user, password: "password123")
    post login_path, params: { email: user.email, password: password }
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
end
