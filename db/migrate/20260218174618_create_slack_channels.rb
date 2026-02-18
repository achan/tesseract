class CreateSlackChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :slack_channels do |t|
      t.references :workspace, null: false, foreign_key: true
      t.text :channel_id, null: false
      t.text :channel_name
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :slack_channels, [ :workspace_id, :channel_id ], unique: true
  end
end
