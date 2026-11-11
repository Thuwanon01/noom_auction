# Product Catalog Flow (Draft)

How buyers browse auctions and open one. Builds on the existing auction list (`/auctions`) and detail (`/auctions/:id`) pages.

**Flow:** `Browse list → Search / filter / sort → Open auction detail → Bid (see bidding flow)`

**Who can use it:** everyone, including guests. Bidding requires login and completed onboarding.

---

## 1. Auction list (`/auctions`)

### Card

Each card shows: cover image (or emoji placeholder), title, product category, auction type badge, current price (฿), status badge, and a time label.

| Status | Label | Time label |
|---|---|---|
| live | กำลังประมูล | Countdown to stop (e.g. "เหลือ 5 ชม.") |
| upcoming | เร็วๆ นี้ | Start date and time |
| ended | จบแล้ว | Stop date and time |

The type badge uses: English = ประมูลขึ้นราคา, Dutch = ประมูลลดราคา, Sealed = ประมูลซองปิด.

- For **Sealed** auctions the card shows the starting price, labeled "ราคาเริ่มต้น", because bids are hidden.
- Clicking a card opens the detail page.

### Search, filter and sort

| Control | Options |
|---|---|
| Search | Text over title and category. Debounced, case-insensitive. |
| Status tabs | All, live, upcoming, ended, each with a count |
| Type | English, Dutch, Sealed (multi-select) |
| Category | Multi-select from the product categories |
| Price range | ≤ ฿1,000 · ฿1,001–3,000 · ฿3,001–10,000 · ฿10,001–50,000 · ฿50,001–100,000 · > ฿100,000 |
| Sort | ใกล้ปิดก่อน (default), ราคาต่ำ → สูง, ราคาสูง → ต่ำ |

- Filters combine with AND. Selected filters show as removable chips plus a **Clear all** link.
- Filters live in the URL query string (`?status=live&price=1001-3000&sort=price_asc&page=2`), so pages can be bookmarked and shared.
- Default order groups live first, then upcoming, then ended, and sorts by stop time inside each group.
- Changing any filter or sort resets to page 1.

### Pagination

- 6 items per page, with Prev / Next and page numbers.
- An out-of-range `page` is clamped to the nearest valid page.

### Empty and error states

| State | Message | Action |
|---|---|---|
| No results | "ไม่พบรายการที่ตรงกับเงื่อนไข" | Clear all filters |
| No auctions yet | "ยังไม่มีรายการประมูล" | None |
| Load error | "โหลดข้อมูลไม่สำเร็จ" | Retry |

## 2. Auction detail (`/auctions/:id`)

- **Gallery:** cover image plus thumbnails.
- **Header:** title, category, condition, type badge, status badge, seller name (masked).
- **Price box:** current price, minimum next bid (current + increment), bid count, and a countdown to stop.
- **Description:** brand, model, year, condition, and any proof-of-authenticity badge.
- **Bid history:** table of user, price and time, newest first. Usernames are partly masked (e.g. `cc***`). For Sealed auctions the table is hidden until the auction ends, and only the bid count is shown.
- **Action area** depends on state:

| Viewer | live | upcoming | ended |
|---|---|---|---|
| Guest | "Log in to bid" | "Log in" | Result |
| Not onboarded | "Complete your profile to bid" | Same | Result |
| Eligible buyer | Bid form (see [bidding flow](biddingFlow.md)) | "Remind me" | Result |
| Seller of this item | "This is your item", no bid form | Edit link until start | Result |

- An unknown `id` returns 404 with a "not found" page and a link back to the list.
- The ended result shows the winning price, or "ไม่มีผู้ชนะ" if the reserve was not met or there were no bids.

## Data needed from the auction record

```
id, title, type, product (category), cover image, status (derived),
current price, start_at, stop_at, bid count, bid increment, seller
status = upcoming if now < start_at; ended if now > stop_at; otherwise live
```

## Open points to confirm

1. Should guests be able to see bid history, or only logged-in users?
2. Is a watchlist or favorites feature needed?
3. Should ended auctions stay in the list, or move to a separate history page after some days?
4. Is the current Thai-only UI the final language, or do we need English as well?
