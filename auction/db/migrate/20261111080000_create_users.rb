# Minimal stub of M1.1 (#7): only the columns the bidding flow needs.
# The full onboarding model (national_id, phone, encryption, ...) extends this table.
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :onboarding_status, null: false, default: "not_started"
      t.integer :credit_score
      t.string :credit_grade
      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
