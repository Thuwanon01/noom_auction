class AddPaidAtToAuctions < ActiveRecord::Migration[8.1]
  def change
    add_column :auctions, :paid_at, :datetime
    add_index :auctions, [ :status, :payment_due_at ]
  end
end
