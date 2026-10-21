class AddOverdueAfterHoursToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :overdue_after_hours, :integer, default: 24, null: false
  end
end
