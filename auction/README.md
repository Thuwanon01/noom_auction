# Noom Auction

Rails 8.1 app (Ruby 4.0, SQLite, Hotwire). Requirement docs live in
[`../requirement`](../requirement).

## Run locally

```sh
bundle install
bin/rails db:prepare   # creates the database and loads db/seeds.rb
bin/dev                # or: bin/rails server
```

Open http://localhost:3000.

Seeded accounts (password `password123`):

| Email | State |
|---|---|
| `done@example.com` | Onboarding completed (grade B) |
| `new@example.com` | Not started; logging in starts onboarding |

## User onboarding flow (M1)

Spec: [`requirement/onboardingFlow.md`](../requirement/onboardingFlow.md)

1. Register at `/register` (or log in as `new@example.com`). You land on `/onboarding/1`.
2. **Step 1:** enter a national ID with a valid checksum (for example `1234567890121`)
   and a phone number starting with 06, 08 or 09, then click **ส่ง OTP**.
   No SMS is sent locally. The code is written to the Rails log:

   ```
   [OTP mock] code for 0812345678: 493027
   ```

   Find it with `tail -f log/development.log | grep "OTP mock"`. Enter it, click
   **ยืนยัน OTP**, accept PDPA, then click **ถัดไป**.
3. **Step 2:** occupation, annual income and years of experience.
4. **Step 3:** the score is calculated on the server (`CreditScoring`).
5. **Step 4:** check the result and the masked summary, tick the confirmation box,
   then confirm. You land on `/auctions`.

Leaving part way and visiting `/onboarding` again resumes at the step you reached.

### Pieces

| What | Where |
|---|---|
| Wizard controller (steps, OTP actions) | `app/controllers/onboarding_controller.rb` |
| Login helpers (`current_user`, `require_login`) | `app/controllers/concerns/authentication.rb` |
| Gate for later milestones (`require_onboarded`) | `app/controllers/concerns/onboarding_gate.rb` |
| OTP service and mock SMS adapter | `app/services/otp_service.rb`, `app/services/otp_adapters/mock.rb` |
| Scoring model (tables, versions, boundaries) | `app/services/credit_scoring.rb` |
| ID and phone validators | `app/validators/` |

### Configuration

- **OTP delivery:** `config.x.otp_adapter` is set to `"OtpAdapters::Mock"` in
  development and test. Production needs a real adapter: any class with
  `deliver(phone:, code:)`. The mock refuses to run in production.
- **Encryption of `users.national_id`:** development and test use fixed,
  non-secret keys. In production, put keys under `active_record_encryption:` in
  credentials (generate them with `bin/rails db:encryption:init`), or set
  `AR_ENCRYPTION_PRIMARY_KEY`, `AR_ENCRYPTION_DETERMINISTIC_KEY` and
  `AR_ENCRYPTION_KEY_DERIVATION_SALT`.

## Tests

```sh
bin/rails test          # models, services, validators, requests
bin/rails test:system   # end-to-end onboarding flow (rack_test, no browser needed)
bin/rubocop
```
