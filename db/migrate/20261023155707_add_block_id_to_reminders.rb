class AddBlockIdToReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :reminders, :block_id, :string
    add_index :reminders, :block_id, unique: true
    # A line can now repeat: a copy of another reminder's line has that reminder's ID until it gets its own.
    remove_index :reminders, [:note_path, :line, :directive], unique: true
  end
end
