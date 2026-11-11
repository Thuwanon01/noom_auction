require "test_helper"

# db/seeds.rb only runs in development; load it here with Rails.env faked so
# a broken seed (e.g. a user without a password) fails CI instead of
# breaking `bin/rails db:prepare` for the next developer.
class SeedsTest < ActiveSupport::TestCase
  # Seeds run against an empty database in development; fixtures reuse the
  # same product codes (P-0001...), so start from empty tables here.
  setup do
    conn = ActiveRecord::Base.connection
    conn.disable_referential_integrity do
      (conn.tables - %w[schema_migrations ar_internal_metadata]).each { |t| conn.execute("DELETE FROM #{conn.quote_table_name(t)}") }
    end
  end

  def run_seeds
    original = Rails.env
    Rails.env = "development"
    silence_stream($stdout) { load Rails.root.join("db/seeds.rb") }
  ensure
    Rails.env = original
  end

  def silence_stream(stream)
    old = stream.dup
    stream.reopen(File::NULL)
    yield
  ensure
    stream.reopen(old)
  end

  test "seeds run cleanly and are idempotent" do
    assert_nothing_raised { run_seeds }
    counts = [ User.count, Product.count, Auction.count, Bid.count ]
    assert_nothing_raised { run_seeds }
    assert_equal counts, [ User.count, Product.count, Auction.count, Bid.count ]
  end

  test "every seeded account can log in with password123" do
    run_seeds
    %w[done@example.com new@example.com seller@example.com admin@example.com].each do |email|
      user = User.find_by(email: email)
      assert user, "#{email} was not seeded"
      assert user.authenticate("password123"), "#{email} cannot log in with password123"
    end
    assert User.find_by(email: "admin@example.com").admin?
  end
end
