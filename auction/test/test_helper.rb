ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
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

class ActionDispatch::IntegrationTest
  # Signs in through the dev-only route (see CurrentUserStub); replace when M1.2 adds real login.
  def login_as(user)
    post dev_login_path, params: { user_id: user.id }
  end
end
