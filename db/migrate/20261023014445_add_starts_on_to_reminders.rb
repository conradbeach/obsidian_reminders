class AddStartsOnToReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :reminders, :starts_on, :date
  end
end
