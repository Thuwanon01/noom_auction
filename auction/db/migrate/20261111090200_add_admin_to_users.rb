# M2.8 (#25): admins review submitted products. There is no UI to grant it; set it from the console or seeds.
class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin, :boolean, null: false, default: false
  end
end
