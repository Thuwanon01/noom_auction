# M3.1 (#27): description fields the detail page shows (from the M2.1 spec)
# and indexes for the catalog list queries.
class AddCatalogFieldsAndIndexes < ActiveRecord::Migration[8.1]
  def change
    change_table :products, bulk: true do |t|
      t.string :brand
      t.string :model
      t.string :year
      t.index :category
      t.index :status
    end

    add_index :auctions, :start_at
    add_index :auctions, :stop_at
    add_index :auctions, :current_price
    add_index :auctions, :auction_type
  end
end
