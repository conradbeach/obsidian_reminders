class AddMissingSinceToReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :reminders, :missing_since, :datetime
  end
end
