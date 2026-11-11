# M3.1 (#27): indexes for the catalog list queries. (brand/model/year and the products.status index come from
# M2.1, see AddListingFieldsToProducts.)
class AddCatalogIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :products, :category
    add_index :auctions, :start_at
    add_index :auctions, :stop_at
    add_index :auctions, :current_price
    add_index :auctions, :auction_type
  end
end
