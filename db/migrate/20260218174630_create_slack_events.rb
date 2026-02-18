class CreateSlackEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :slack_events do |t|
      t.references :slack_channel, null: false, foreign_key: true
      t.text :event_id, null: false
      t.text :event_type
      t.text :user_id
      t.text :ts
      t.text :thread_ts
      t.json :payload

      t.timestamps
    end

    add_index :slack_events, :event_id, unique: true
    add_index :slack_events, [ :slack_channel_id, :created_at ]
  end
end
