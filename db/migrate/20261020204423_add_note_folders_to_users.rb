class AddNoteFoldersToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :note_folders, :json, null: false, default: []
  end
end
