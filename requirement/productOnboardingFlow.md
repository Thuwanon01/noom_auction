# Product Onboarding Flow (Draft)

How a seller lists a new product so it can be auctioned.

**Flow:** `Step 1 Product info → Step 2 Photos and proof → Step 3 Auction setup → Step 4 Review and submit`

A progress bar shows 1/4 to 4/4. Each step saves as a draft, so the seller can resume later.

**Who can start:** a logged-in user who has completed [user onboarding](onboardingFlow.md) (`onboarding_status = completed`). Entry point: **Products → New product** (`/products/new`).

---

## Step 1: Product info

| Field | Input | Validation |
|---|---|---|
| Name | Text | Required, 5–100 characters |
| Category | Dropdown: กล้อง, นาฬิกา, เครื่องดนตรี, ไอที, กีฬา, ของสะสม, เฟอร์นิเจอร์, ศิลปะ, ยานพาหนะ, Other | Required |
| Condition | Radio: New, Like new, Good, Fair, For parts | Required |
| Description | Textarea | Required, 20–2,000 characters |
| Brand / model / year | Text, optional | Max 100 characters each |

## Step 2: Photos and proof

| Field | Rule |
|---|---|
| Photos | 1–8 images, JPG or PNG, max 5 MB each. The first image is the cover. Drag to reorder. At least 1 is required. |
| Proof of authenticity | Required for **ของสะสม** and **ยานพาหนะ** (certificate, receipt or registration). Optional for other categories. PDF or image. |

- Show the hint "Clear photos from several angles get more bids".
- Show an upload progress bar for each file. A failed upload shows Retry without losing the other files.

## Step 3: Auction setup

| Field | Input | Validation |
|---|---|---|
| Auction type | Radio: **English** (ประมูลขึ้นราคา), **Dutch** (ประมูลลดราคา), **Sealed** (ประมูลซองปิด) | Required |
| Starting price (THB) | Number | Required, ≥ 100 |
| Reserve price (THB) | Number, optional | ≥ starting price. Hidden from bidders. |
| Start at / stop at | Date-time pickers | Start ≥ now + 1 hour. Stop − start between 1 hour and 14 days. |

Fields that depend on the type:

| Type | Extra fields |
|---|---|
| English | Bid increment (default ฿100, min ฿10) |
| Dutch | Floor price (≥ 1 and < starting price), price drop amount, drop interval (1–60 minutes) |
| Sealed | None. Bids stay hidden until the auction closes. |

- Show a type explainer next to the radio buttons, and a live preview of the auction card.

## Step 4: Review and submit

- Show a read-only summary of all steps with an **Edit** link back to each one.
- Show a checkbox: "I own this item and the information is true. I accept the seller terms."
- **Submit** sets the product to `pending_review` and shows "Submitted. We will review it within 24 hours".
- **Save as draft** keeps the product with `draft` status and returns to the product list.

---

## Product status lifecycle

```
draft → pending_review → available → in_event → sold
                │            │          │
                └→ rejected  └→ withdrawn   └→ unsold (reserve not met / no bids) → available
```

| Status | Meaning | Label (existing UI) |
|---|---|---|
| draft | Seller is still editing | แบบร่าง |
| pending_review | Waiting for admin review | รอตรวจสอบ |
| rejected | Admin rejected, with a reason. The seller can edit and resubmit. | ไม่ผ่าน |
| available | Approved, not yet in an auction | พร้อมประมูล |
| in_event | Scheduled or live in an auction | อยู่ในอีเวนต์ |
| sold | Auction won and paid | ขายแล้ว |

- An `in_event` product cannot be edited or deleted.
- The product code is generated on first save as `P-0001`, `P-0002`, … and is unique.

## Suggested data

```
products: code (unique), seller_id, name, category, condition, description,
          brand, model, year, status, rejection_reason
product_images: product_id, position, file
product_documents: product_id, kind, file
auctions: product_id, type, start_price, reserve_price, bid_increment,
          floor_price, price_drop, drop_interval_minutes, start_at, stop_at
```

## Open points to confirm

1. Does every product need admin review, or only some categories?
2. Can a seller with credit grade D list products?
3. Is there a listing fee or seller commission?
4. Should sellers be able to edit start and stop times after approval, as long as the auction has not started?
