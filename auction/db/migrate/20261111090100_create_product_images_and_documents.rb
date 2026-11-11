# M2.1 (#18): files are stored with Active Storage (has_one_attached :file).
class CreateProductImagesAndDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :product_images do |t|
      t.references :product, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :product_images, [ :product_id, :position ]

    create_table :product_documents do |t|
      t.references :product, null: false, foreign_key: true
      t.string :kind, null: false, default: "proof"
      t.timestamps
    end
  end
end
