# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_11_090200) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "auctions", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "auction_type", null: false
    t.integer "start_price", null: false
    t.integer "reserve_price"
    t.integer "bid_increment", default: 100, null: false
    t.integer "floor_price"
    t.integer "price_drop"
    t.integer "drop_interval_minutes"
    t.datetime "start_at", null: false
    t.datetime "stop_at", null: false
    t.integer "current_price", null: false
    t.string "status", default: "open", null: false
    t.integer "winner_id"
    t.datetime "closed_at"
    t.integer "extension_count", default: 0, null: false
    t.datetime "payment_due_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_auctions_on_product_id", unique: true
    t.index ["status", "stop_at"], name: "index_auctions_on_status_and_stop_at"
    t.index ["winner_id"], name: "index_auctions_on_winner_id"
  end

  create_table "bids", force: :cascade do |t|
    t.integer "auction_id", null: false
    t.integer "user_id", null: false
    t.integer "amount", null: false
    t.datetime "placed_at", null: false
    t.string "idempotency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auction_id", "amount", "placed_at"], name: "index_bids_on_auction_ranking", order: { amount: :desc }
    t.index ["user_id", "auction_id", "idempotency_key"], name: "index_bids_on_user_auction_idempotency", unique: true
    t.index ["user_id"], name: "index_bids_on_user_id"
  end

  create_table "product_documents", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "kind", default: "proof", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_documents_on_product_id"
  end

  create_table "product_images", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "position"], name: "index_product_images_on_product_id_and_position"
    t.index ["product_id"], name: "index_product_images_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "code", null: false
    t.integer "seller_id", null: false
    t.string "name", null: false
    t.string "category"
    t.string "condition"
    t.text "description"
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "brand"
    t.string "model"
    t.integer "year"
    t.text "rejection_reason"
    t.index ["code"], name: "index_products_on_code", unique: true
    t.index ["seller_id"], name: "index_products_on_seller_id"
    t.index ["status"], name: "index_products_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "onboarding_status", default: "not_started", null: false
    t.integer "credit_score"
    t.string "credit_grade"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "auctions", "products"
  add_foreign_key "auctions", "users", column: "winner_id"
  add_foreign_key "bids", "auctions"
  add_foreign_key "bids", "users"
  add_foreign_key "product_documents", "products"
  add_foreign_key "product_images", "products"
  add_foreign_key "products", "users", column: "seller_id"
end
