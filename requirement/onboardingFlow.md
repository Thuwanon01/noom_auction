# User Onboarding Flow (Draft)

**Flow:** `Step 1 Identity → Step 2 Financial profile → Step 3 Credit scoring → Step 4 Result and confirm`

A progress bar shows 1/4 to 4/4. Each step saves as a draft, so a user who leaves can resume where they stopped.

---

## Step 1: National ID and phone number

| Field | Rule |
|---|---|
| National ID | 13 digits. Checksum: `(11 − (Σ digit[i] × (13 − i), i=0..11) mod 11) mod 10 == digit[12]`. Must not already be registered. |
| Phone number | 10 digits, starting with `06`, `08` or `09`. Must not already be registered. |

- **Verification:** send an OTP (6 digits, 5-minute expiry, 3 attempts) to the phone number.
- **Consent:** a PDPA checkbox is required before continuing.
- **Next:** enabled only when the ID is valid and the OTP is verified.
- **Errors:** "Invalid ID number", "This ID is already registered", "Wrong OTP (2 attempts left)".

## Step 2: Occupation, annual income and years of experience

| Field | Input | Validation |
|---|---|---|
| Occupation | Dropdown: Government/State enterprise, Private employee, Business owner, Freelance/Professional, Student/Unemployed, Other | Required |
| Annual income (THB) | Number, with a thousands separator | Required, > 0, ≤ 100,000,000 |
| Years of experience | Number, 0–50 (decimals allowed, e.g. 1.5) | Required, and must be consistent with the user's age if a birth date is known |

- Show the hint "Total income before tax, from all sources".
- **Back** keeps the Step 1 data. **Next** saves a draft.

## Step 3: Credit scoring (system step)

The screen shows a short "Calculating your score…" state. The score is computed server-side, not in the client.

**Draft scoring model (range 300–850):**

`score = 300 + occupation_pts + income_pts + experience_pts`

| Occupation | Pts | Annual income (THB) | Pts | Experience | Pts |
|---|---|---|---|---|---|
| Government/State enterprise | 150 | < 120k | 30 | 0 | 0 |
| Private employee | 120 | 120k–300k | 90 | < 1 yr | 20 |
| Business owner | 100 | 300k–600k | 150 | 1–3 yrs | 60 |
| Freelance/Professional | 90 | 600k–1.2M | 210 | 3–5 yrs | 100 |
| Other | 60 | > 1.2M | 250 | 5–10 yrs | 130 |
| Student/Unemployed | 40 | | | 10+ yrs | 150 |

**Grades:**

| Score | Grade |
|---|---|
| 750+ | A |
| 650–749 | B |
| 550–649 | C |
| < 550 | D |

- Store the score, grade, model version and the inputs used, so results can be audited and the model changed later.
- **On error or timeout:** show "Something went wrong" with a Retry button. Inputs are kept.

## Step 4: Display result and confirm

- Show the score on a gauge or large number, with the grade and a one-line meaning (e.g. "B: Good").
- Show a "How we calculated this" breakdown of occupation, income and experience points.
- Show a summary of the submitted data. Mask the ID as `1-2345-XXXXX-XX-3` and the phone as `08X-XXX-1234`. Each item has an **Edit** link back to its step. Editing re-runs Step 3.
- Show a checkbox: "I confirm the information is true".
- **Confirm** creates the account or profile, sets `onboarding_status = completed`, and redirects to the auction home page.
- **Back** returns to Step 2.

---

## Suggested state and data

```
onboarding_status: not_started | step1 | step2 | step3 | completed
users: national_id (unique, encrypted), phone (unique), occupation,
       annual_income, years_experience, credit_score, credit_grade,
       score_model_version, confirmed_at
```

## Open points to confirm

1. Is the scoring model above a placeholder, or is there an existing rule set?
2. Should a grade D user be blocked from bidding, or only given a lower bid limit?
3. Is OTP verification in scope, or should it be mocked for now?
4. Should this be built as a Rails multi-step form in this repo, or just a UI mockup?
