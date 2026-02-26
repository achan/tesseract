class CreateFeedItems < ActiveRecord::Migration[8.0]
  def change
    create_table :feed_items do |t|
      t.references :feed, null: false, foreign_key: true
      t.text :source_type, null: false
      t.integer :source_id, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :feed_items, [:feed_id, :occurred_at]
    add_index :feed_items, [:source_type, :source_id]
  end
end
