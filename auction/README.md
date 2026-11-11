# README

## Seller flow: listing a product (M2)

Spec: [requirement/productOnboardingFlow.md](../requirement/productOnboardingFlow.md)

```bash
bin/rails db:setup        # creates the database and loads demo data (seeds are safe to run again)
bin/dev                   # or: bin/rails server
```

Seeds create a completed seller (`seller@example.com`) and an admin (`admin@example.com`, development only).
Real login is not built yet (M1.2, #8), so use the temporary dev sign-in (development and test only):

Open `http://localhost:3000/dev/login/<user id>` in the browser.

Find ids with `bin/rails runner 'puts User.pluck(:id, :email)'`.

| Step | Where | What happens |
|---|---|---|
| 1 Product info | `/products/new` | creates a `draft` with code `P-0001`... |
| 2 Photos and proof | `/products/:id/steps/2` | 1-8 JPG/PNG photos, proof for collectibles and vehicles |
| 3 Auction setup | `/products/:id/steps/3` | English, Dutch or Sealed, prices, times |
| 4 Review and submit | `/products/:id/steps/4` | submit -> `pending_review`, or save as draft |
| Admin review | `/admin/products` (admin only) | approve -> `available`, reject with a reason -> `rejected` |
| My products | `/my/products` | status, continue a draft, resubmit after a rejection |

Status lifecycle: `draft -> pending_review -> available -> in_event -> sold`, with `rejected` (editable, can resubmit)
and `withdrawn`. An `in_event` product cannot be edited or deleted.

### Tests

```bash
bin/rails test           # models and full-flow request tests (no browser needed)
bin/rails test:system    # real-browser tests for the upload and auction-setup JavaScript (needs Chrome)
```

---

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
