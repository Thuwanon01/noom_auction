class CreateOtpChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :otp_challenges do |t|
      t.string :phone, null: false
      t.string :code_digest, null: false # HMAC of the code; the code itself is never stored
      t.datetime :expires_at, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :verified_at
      t.timestamps
    end

    add_index :otp_challenges, %i[phone created_at]
  end
end
