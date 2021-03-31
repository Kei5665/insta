class ChangeUserToUsers < ActiveRecord::Migration[5.2]
  def change
    rename_table :User, :users
  end
end
