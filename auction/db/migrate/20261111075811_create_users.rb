class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # Step 1: identity. national_id is encrypted (deterministic) in the model.
      t.string :national_id
      t.string :phone
      t.datetime :phone_verified_at
      t.datetime :pdpa_consented_at
      t.date :birth_date

      # Step 2: financial profile
      t.string :occupation
      t.decimal :annual_income, precision: 12, scale: 2
      t.decimal :years_experience, precision: 3, scale: 1

      # Step 3: latest credit score (full history lives in credit_scores)
      t.integer :credit_score
      t.string :credit_grade
      t.string :score_model_version

      # Step 4
      t.datetime :confirmed_at

      t.string :onboarding_status, null: false, default: "not_started"

      t.timestamps
    end

    add_index :users, :national_id, unique: true
    add_index :users, :phone, unique: true
  end
end
