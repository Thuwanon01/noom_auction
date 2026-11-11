# Integration of M1 (users) with M2/M3/M4. Those milestones show a seller/bidder name and M2.8 has an admin review
# queue. Both are optional so the M1 registration form does not need to change.
class AddNameAndAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string
    add_column :users, :admin, :boolean, null: false, default: false
  end
end
