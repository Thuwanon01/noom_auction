require "application_system_test_case"

# M4.9 (#45) acceptance: two browser sessions; a bid in one updates the
# other without a reload.
class LiveUpdatesJsTest < JsSystemTestCase
  setup do
    # Broadcast jobs must really run (and reach Action Cable) in this test.
    @original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :async
    @auction = auctions(:english)
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_adapter
  end

  test "a bid in one session updates the other without reload" do
    using_session(:watcher) do
      sign_in_as users(:other_buyer)
      visit auction_path(@auction)
      assert_selector "[data-testid=current-price]", text: "฿1,000"
      assert_selector "turbo-cable-stream-source[connected]", visible: false
      page.execute_script("window.__noReload = true")
    end

    using_session(:bidder) do
      sign_in_as users(:buyer)
      visit auction_path(@auction)
      click_button "฿1,500"
      click_button "เสนอราคา"
      within("dialog.confirm-dialog[open]") { click_button "Confirm" }
      assert_selector ".bid-flash--success", text: "You are the highest bidder"
    end

    using_session(:watcher) do
      assert_selector "[data-testid=current-price]", text: "฿1,500", wait: 10
      assert_selector ".table tbody tr", count: 1
      assert_selector "input[name=amount][min='1600']"
      assert page.evaluate_script("window.__noReload"), "the page was fully reloaded"
    end
  end

  test "the watcher keeps what they are typing when a refresh arrives" do
    using_session(:watcher) do
      sign_in_as users(:other_buyer)
      visit auction_path(@auction)
      assert_selector "turbo-cable-stream-source[connected]", visible: false
      fill_in "amount", with: "1234"
    end

    PlaceBid.call(user: users(:buyer), auction: @auction, amount: 1_500, idempotency_key: "bg")

    using_session(:watcher) do
      assert_selector "[data-testid=current-price]", text: "฿1,500", wait: 10
      assert_equal "1234", find_field("amount").value
    end
  end
end
