# Minimal stub of M2.1 (#18): only the columns the bidding flow needs.
class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :code, null: false
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :category
      t.string :condition
      t.text :description
      t.string :status, null: false, default: "draft"
      t.timestamps
    end
    add_index :products, :code, unique: true
  end
end
