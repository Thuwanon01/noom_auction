class CreateBids < ActiveRecord::Migration[8.1]
  def change
    create_table :bids do |t|
      t.references :auction, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.integer :amount, null: false
      t.datetime :placed_at, null: false
      t.string :idempotency_key, null: false
      t.timestamps
    end
    add_index :bids, [ :auction_id, :amount, :placed_at ], order: { amount: :desc, placed_at: :asc }, name: "index_bids_on_auction_ranking"
    add_index :bids, [ :user_id, :auction_id, :idempotency_key ], unique: true, name: "index_bids_on_user_auction_idempotency"
  end
end
