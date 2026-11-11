require "test_helper"

# M3.9 (#35): one test per cell of the viewer x phase table.
class AuctionActionStateTest < ActiveSupport::TestCase
  include CatalogFactory

  NOW = Time.zone.local(2026, 11, 11, 12, 0)

  PHASE_TIMES = {
    live:     { start_at: NOW - 1.hour, stop_at: NOW + 1.hour },
    upcoming: { start_at: NOW + 1.hour, stop_at: NOW + 1.day },
    ended:    { start_at: NOW - 1.day,  stop_at: NOW - 1.hour }
  }.freeze

  VIEWERS = {
    guest:         -> { nil },
    not_onboarded: -> { users(:newbie) },
    buyer:         -> { users(:buyer) },
    seller:        -> { users(:seller) }
  }.freeze

  EXPECTED = {
    guest:         { live: :login_to_bid,     upcoming: :login,            ended: :result },
    not_onboarded: { live: :complete_profile, upcoming: :complete_profile, ended: :result },
    buyer:         { live: :bid_form,         upcoming: :remind_me,        ended: :result },
    seller:        { live: :own_item,         upcoming: :edit_until_start, ended: :result }
  }.freeze

  EXPECTED.each do |viewer, row|
    row.each do |phase, state|
      test "#{viewer} on #{phase} auction sees #{state}" do
        auction = create_auction(**PHASE_TIMES.fetch(phase))
        viewer_user = instance_exec(&VIEWERS.fetch(viewer))
        assert_equal state, AuctionActionState.for(viewer: viewer_user, auction: auction, now: NOW)
      end
    end
  end

  test "a buyer over the bid limit still sees the bid form" do
    auction = create_auction(price: 500_000, **PHASE_TIMES[:live])
    assert_equal :bid_form, AuctionActionState.for(viewer: users(:other_buyer), auction: auction, now: NOW)
  end
end
