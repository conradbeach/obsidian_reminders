class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders do |t|
      t.string :note_path, null: false
      t.string :line, null: false
      t.string :directive, null: false
      t.datetime :remind_at
      t.datetime :notified_at

      t.timestamps
    end
    add_index :reminders, [:note_path, :line, :directive], unique: true
    add_index :reminders, :remind_at
  end
end
