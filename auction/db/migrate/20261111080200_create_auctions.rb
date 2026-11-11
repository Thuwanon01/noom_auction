# Setup columns follow M2.1 (#18); closing columns are M4.1 (#37).
# Money is whole baht stored as integers.
class CreateAuctions < ActiveRecord::Migration[8.1]
  def change
    create_table :auctions do |t|
      t.references :product, null: false, foreign_key: true, index: { unique: true }
      t.string :auction_type, null: false
      t.integer :start_price, null: false
      t.integer :reserve_price
      t.integer :bid_increment, null: false, default: 100
      t.integer :floor_price
      t.integer :price_drop
      t.integer :drop_interval_minutes
      t.datetime :start_at, null: false
      t.datetime :stop_at, null: false

      # M4.1 closing fields
      t.integer :current_price, null: false
      t.string :status, null: false, default: "open"
      t.references :winner, foreign_key: { to_table: :users }
      t.datetime :closed_at
      t.integer :extension_count, null: false, default: 0
      t.datetime :payment_due_at
      t.timestamps
    end
    add_index :auctions, [ :status, :stop_at ]
  end
end
