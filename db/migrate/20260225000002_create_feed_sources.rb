class CreateFeedSources < ActiveRecord::Migration[8.0]
  def change
    create_table :feed_sources do |t|
      t.references :feed, null: false, foreign_key: true
      t.text :source_type, null: false
      t.integer :source_id, null: false
      t.timestamps
    end
    add_index :feed_sources, [:feed_id, :source_type, :source_id], unique: true
    add_index :feed_sources, [:source_type, :source_id]
  end
end
