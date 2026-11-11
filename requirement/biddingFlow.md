# Bidding Flow (Draft)

How a buyer places a bid and how an auction ends. The rules differ by auction type.

**Flow:** `Check eligibility → Place bid → Confirm → Result of bid → Auction closes → Winner and payment`

Entry point: the action area on the auction detail page (see [product catalog flow](productCatalogFlow.md)).

---

## 1. Eligibility

A bid is accepted only when all of these are true. The server checks every one on each bid, not only the UI.

| Rule | If it fails |
|---|---|
| User is logged in | "Log in to bid" |
| Onboarding is completed ([user onboarding](onboardingFlow.md)) | "Complete your profile to bid" |
| User is not the seller | "You cannot bid on your own item" |
| Auction is live (`start_at ≤ now < stop_at`) | "This auction is not open for bidding" |
| Bid is within the user's bid limit (by credit grade) | "Over your bid limit. Your limit is ฿X" |

Draft bid limit by credit grade:

| Grade | Highest single bid |
|---|---|
| A (750+) | No limit |
| B (650–749) | ฿200,000 |
| C (550–649) | ฿50,000 |
| D (< 550) | ฿10,000 |

## 2. English auction (ประมูลขึ้นราคา)

1. The price box shows the current price and the **minimum bid = current price + increment** (default ฿100).
2. The user types an amount or taps a quick button (+min, +2×, +5×).
3. **Validation:** a whole number, ≥ minimum bid, and within the bid limit.
4. A confirm dialog shows "Bid ฿X on {title}? A bid cannot be withdrawn." with **Confirm** and **Cancel**.
5. The server saves the bid in a transaction, locking the auction row. If another bid arrived first and the amount is now below the minimum, reject with "Price changed. The new minimum is ฿Y" and refresh the price.
6. On success the page shows "You are the highest bidder", the bid history updates, and the previous top bidder is notified "You were outbid".
7. **Anti-sniping:** a bid placed in the last 2 minutes extends `stop_at` by 2 minutes, up to 10 extensions.
8. A user who is already the highest bidder cannot bid again until someone outbids them.

## 3. Dutch auction (ประมูลลดราคา)

1. The price starts at the starting price and drops by the **price drop** every **drop interval**, down to the **floor price**. It never goes below the floor.
2. The page shows the current price, a countdown to the next drop, and one button: **Buy now at ฿X**.
3. The user taps the button and a confirm dialog shows the price at that moment.
4. The server accepts only the **first** accepted bid. It uses the server's price at the time of the request, not the price shown on the client. If the price dropped in between, the dialog shows the new price and asks again.
5. The first accepted bid wins and the auction closes immediately. Other users see "Sold".
6. If the price reaches the floor with no bidder, the auction continues at the floor price until `stop_at`, then ends unsold.

## 4. Sealed auction (ประมูลซองปิด)

1. The user sees the starting price and the number of bids. Other bids and amounts are hidden.
2. The user enters one amount, which must be ≥ the starting price and within the bid limit.
3. A confirm dialog shows "Submit a sealed bid of ฿X?".
4. A user may **revise** their bid up to `stop_at`. The new amount replaces the old one. A bid cannot be withdrawn.
5. Bids are revealed only after the auction closes.
6. **Ties:** the earliest bid wins.

## 5. Auction closes

At `stop_at` (including any extension), a background job closes the auction:

| Case | Result |
|---|---|
| Highest bid ≥ reserve (or no reserve) | Winner is the highest bidder. Product status → `sold`, pending payment. |
| Highest bid < reserve | No winner ("ไม่มีผู้ชนะ"). Product → `available`. |
| No bids | Ended unsold. Product → `available`. |

- The winner and the seller are notified.
- The winner has **48 hours** to pay. If they do not, the sale is cancelled and the product returns to `available`. Offering the item to the next-highest bidder is an open point (see below).
- Non-winning bidders are told "Auction ended. You did not win".

## 6. Bid history and "my bids"

- The auction page shows the bid table (user, price, time), newest first, with partly masked usernames. Sealed auctions hide it until closing.
- A **My bids** page lists the user's auctions with a status: Winning, Outbid, Won, Lost.

## Error states

| Case | Message |
|---|---|
| Bid below minimum | "The minimum bid is ฿X" |
| Not a number or ≤ 0 | "Enter a valid amount" |
| Auction ended while bidding | "This auction has just ended" |
| Network failure | "Could not place your bid. Please try again" (the bid is not assumed to be placed) |
| Duplicate submit | Disable the button while the request runs, and use an idempotency key |

## Suggested data

```
bids: auction_id, user_id, amount, placed_at, idempotency_key
auctions: current_price, winner_id, closed_at, extension_count, status
index: bids(auction_id, amount desc, placed_at asc)
```

Live price and bid history updates should come from Turbo Streams or polling.

## Open points to confirm

1. Is the bid limit by credit grade correct, and should it apply to Dutch purchases too?
2. If the winner does not pay, should the item go to the next-highest bidder or be relisted?
3. Are the anti-sniping numbers (2 minutes, 10 extensions) acceptable?
4. Is payment in scope, or only "winner chosen"?
5. Should the platform charge a buyer's premium or deposit?
