class AddEndsOnToReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :reminders, :ends_on, :date
  end
end
