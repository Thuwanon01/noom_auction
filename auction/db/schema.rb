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

ActiveRecord::Schema[8.1].define(version: 2026_11_11_080010) do
  create_table "users", force: :cascade do |t|
    t.string "national_id"
    t.string "phone"
    t.datetime "phone_verified_at"
    t.datetime "pdpa_consented_at"
    t.date "birth_date"
    t.string "occupation"
    t.decimal "annual_income", precision: 12, scale: 2
    t.decimal "years_experience", precision: 3, scale: 1
    t.integer "credit_score"
    t.string "credit_grade"
    t.string "score_model_version"
    t.datetime "confirmed_at"
    t.string "onboarding_status", default: "not_started", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.string "password_digest"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["national_id"], name: "index_users_on_national_id", unique: true
    t.index ["phone"], name: "index_users_on_phone", unique: true
  end
end
