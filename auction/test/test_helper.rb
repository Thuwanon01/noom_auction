ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Replace a singleton method for the duration of the block (minitest 6 has no stubs).
    def with_singleton_stub(object, name, impl)
      original = object.method(name)
      object.define_singleton_method(name, &impl)
      yield
    ensure
      object.define_singleton_method(name, original)
    end
  end
end

module SignInHelper
  def sign_in_as(user)
    post test_sign_in_path, params: { user_id: user.id }
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
end
