require "application_system_test_case"

# M3.4 (#30) and M3.10 (#36): the catalog flow end to end.
class CatalogFlowTest < ApplicationSystemTestCase
  include CatalogFactory

  setup do
    # 3 fixture auctions (live English, Dutch, Sealed) + 8 more = 11 public auctions, 2 pages.
    8.times { |i| create_auction(name: "Camera Lot #{i}", category: "camera", type: "english", price: 1_000 + i * 500) }
    create_auction(name: "Upcoming Guitar", category: "instrument", type: "english", start_at: 1.day.from_now, stop_at: 2.days.from_now)
    create_auction(name: "Ended Teak Table", category: "furniture", type: "dutch", start_at: 3.days.ago, stop_at: 1.day.ago)
  end

  test "list, filter, sort, paginate, open detail and come back with filters kept" do
    visit auctions_path
    assert_selector ".card", count: 6
    assert_selector ".pager__link", text: "2"

    find("summary", text: "ประเภท").click
    check "ประมูลขึ้นราคา"
    select "ราคาสูง → ต่ำ", from: "sort"
    click_button "ค้นหา"

    assert_current_path(/type(%5B%5D|\[\])=english/)
    assert_current_path(/sort=price_desc/)
    assert_selector ".active-filters .chip--removable", text: "ประมูลขึ้นราคา"
    assert_equal "Camera Lot 7", first(".card__title").text

    click_link "ถัดไป ›"
    assert_current_path(/page=2/)
    assert_selector ".pager__link--on", text: "2"

    first(".card__title a").click
    assert_selector ".bid-box"
    within(".crumb") { click_link "Event" }

    assert_current_path(/type(%5B%5D|\[\])=english/)
    assert_current_path(/sort=price_desc/)
    assert_current_path(/page=2/)
    assert_selector ".pager__link--on", text: "2"
  end

  test "search, remove a chip and clear all" do
    visit auctions_path(status: "live")
    fill_in "q", with: "camera lot"
    click_button "ค้นหา"
    assert_selector ".card", count: 6
    assert_selector ".chip--removable", text: "ค้นหา: camera lot"
    assert_selector ".chip--removable", text: "กำลังประมูล"

    find(".chip--removable", text: "กำลังประมูล").click
    assert_no_selector ".chip--removable", text: "กำลังประมูล"
    assert_selector ".chip--removable", text: "ค้นหา: camera lot"

    click_link "ล้างทั้งหมด"
    assert_no_selector ".active-filters"
    assert_selector ".toolbar__chips .chip--on", text: "ทั้งหมด"
  end

  test "a copied URL reproduces the same filtered list" do
    visit auctions_path(category: [ "furniture" ], status: "ended")
    assert_selector ".card", count: 1
    assert_selector ".card__title", text: "Ended Teak Table"
  end

  test "no results then clear all filters" do
    visit auctions_path(q: "zzz-nothing")
    assert_text "ไม่พบรายการที่ตรงกับเงื่อนไข"
    click_link "ล้างตัวกรองทั้งหมด"
    assert_selector ".card", count: 6
  end

  test "guest view of a live auction" do
    visit auction_path(auctions(:english))
    assert_link "Log in to bid"
  end

  test "not-onboarded view of a live auction" do
    sign_in_as users(:newbie)
    visit auction_path(auctions(:english))
    assert_link "Complete your profile to bid"
  end

  test "seller view of a live auction" do
    sign_in_as users(:seller)
    visit auction_path(auctions(:english))
    assert_text "This is your item"
    assert_no_selector ".bid-box__form"
  end
end
