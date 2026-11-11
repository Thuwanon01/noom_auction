# M2.1 (#18): fields the seller wizard needs on top of the stub from M4.1.
class AddListingFieldsToProducts < ActiveRecord::Migration[8.1]
  def change
    change_table :products do |t|
      t.string :brand
      t.string :model
      t.integer :year
      t.text :rejection_reason
    end
    add_index :products, :status
  end
end
