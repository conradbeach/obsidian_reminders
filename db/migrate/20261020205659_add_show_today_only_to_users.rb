class AddShowTodayOnlyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :show_today_only, :boolean, null: false, default: false
  end
end
