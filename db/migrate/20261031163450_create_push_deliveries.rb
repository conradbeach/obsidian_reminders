class CreatePushDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :push_deliveries do |t|
      t.references :push_subscription, null: false, foreign_key: true
      t.string :title, null: false
      t.string :receipt_token
      t.datetime :accepted_at
      t.datetime :received_at
      t.datetime :shown_at

      t.timestamps
    end
    add_index :push_deliveries, :receipt_token, unique: true
  end
end
