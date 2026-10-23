class AddUndoToReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :reminders, :undoable_until, :datetime
    add_column :reminders, :undo_remind_at, :datetime
    add_column :reminders, :undo_notified_at, :datetime
  end
end
