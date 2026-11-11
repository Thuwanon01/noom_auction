class CreateCreditScores < ActiveRecord::Migration[8.1]
  def change
    # One row per scoring run, kept for audit. users.credit_score holds the latest.
    create_table :credit_scores do |t|
      t.references :user, null: false, foreign_key: true
      t.json :inputs, null: false       # occupation, annual_income, years_experience as scored
      t.json :breakdown, null: false    # points per factor
      t.integer :score, null: false
      t.string :grade, null: false
      t.string :model_version, null: false
      t.timestamps
    end
  end
end
