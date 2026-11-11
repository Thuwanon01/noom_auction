# Noom Auction

Rails 8.1 app (SQLite, Hotwire, Solid Queue / Cable). Specs live in
[`../requirement`](../requirement).

## Setup

```sh
bin/setup            # bundle, db:prepare
bin/rails db:seed    # demo users, products and auctions (idempotent)
bin/dev              # http://localhost:3000
```

Until real login (M1) lands, the signed-in user is whoever is in
`session[:user_id]` (see `ApplicationController#current_user`).

## Tests

```sh
bin/rails test          # models, services, controllers
bin/rails test:system   # end-to-end scenarios
bin/rubocop
```

### Bidding flow scenarios (M4)

`test/system/bidding_flow_test.rb` drives the whole bidding flow through the
UI. It moves time with `travel_to` and runs the jobs Solid Queue would run at
`stop_at` / `payment_due_at` (`CloseAuctionJob`, `ExpirePaymentJob`) directly:

| Scenario | What it checks |
|---|---|
| English | two bidders, outbid notification, anti-sniping extension, close, winner / loser / seller notified, seller marks paid |
| Dutch | two buyers on the same price: the first wins, the second sees "Sold" |
| Sealed | submit, revise, amounts hidden from others until close, then revealed with the winner |
| Reserve not met | no winner, product back to `available` |
| No bids | ended unsold |
| Unpaid after 48h | sale cancelled, product back to `available`, winner shown as Lost |

Run just these:

```sh
bin/rails test test/system/bidding_flow_test.rb
```

Most system tests use `rack_test` (no browser). Files ending in `_js_test.rb`
use headless Chrome to cover the Stimulus parts: confirm dialogs, quick-bid
buttons, the Dutch re-confirm after a price drop, and live updates between
two browser sessions. They are skipped when Chrome is not installed.

```sh
PARALLEL_WORKERS=1 bin/rails test test/system/*_js_test.rb
```

## Background jobs

- `CloseAuctionJob` is scheduled at each auction's `stop_at` and rescheduled
  when anti-sniping extends it.
- `ExpirePaymentJob` is scheduled at `payment_due_at` (48h after a win).
- `config/recurring.yml` (production) runs `CloseOverdueAuctionsJob` every
  minute and `ExpireUnpaidAuctionsJob` every 10 minutes as safety nets.
