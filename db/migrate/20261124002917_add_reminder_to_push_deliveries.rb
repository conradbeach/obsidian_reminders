class AddReminderToPushDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_reference :push_deliveries, :reminder, foreign_key: { on_delete: :nullify }
  end
end
