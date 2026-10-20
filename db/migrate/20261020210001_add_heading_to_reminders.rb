class AddHeadingToReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :reminders, :heading, :string
  end
end
