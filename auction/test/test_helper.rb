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

    # Temporarily replace a singleton method, e.g. to force CreditScoring to fail.
    # Safe with process-based parallel tests.
    def with_stubbed(object, method_name, implementation)
      original = object.method(method_name)
      object.define_singleton_method(method_name, &implementation)
      yield
    ensure
      object.define_singleton_method(method_name, original)
    end

    PNG_BYTES = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")
    PDF_BYTES = "%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[]/Count 0>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n"

    # Uploaded-file builders for tests. `padding` grows the file (to test size limits) without breaking its type.
    def upload(bytes, type, name, padding: 0)
      io = StringIO.new(bytes + ("\0" * padding))
      Rack::Test::UploadedFile.new(io, type, true, original_filename: name)
    end

    def png_upload(name = "photo.png", padding: 0) = upload(PNG_BYTES, "image/png", name, padding: padding)
    def pdf_upload(name = "proof.pdf") = upload(PDF_BYTES, "application/pdf", name)
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
