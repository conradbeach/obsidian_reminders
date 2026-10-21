class AddRemindersNoteToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :reminders_note, :string
  end
end
