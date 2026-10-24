class AddIgnoredFoldersToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :ignored_folders, :json, default: [], null: false
  end
end
