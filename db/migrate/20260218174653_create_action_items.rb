class CreateActionItems < ActiveRecord::Migration[8.0]
  def change
    create_table :action_items do |t|
      t.references :summary, null: false, foreign_key: true
      t.text :source_type
      t.integer :source_id
      t.text :description, null: false
      t.text :assignee_user_id
      t.text :source_ts
      t.text :status, default: "open", null: false

      t.timestamps
    end

    add_index :action_items, :status
    add_index :action_items, [ :source_type, :source_id ]
  end
end
