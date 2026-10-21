class AddNotesToReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :reminders, :notes, :text
  end
end
