class AddCompletedAtToReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :reminders, :completed_at, :datetime
  end
end
