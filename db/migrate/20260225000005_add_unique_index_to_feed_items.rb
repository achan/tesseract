class AddUniqueIndexToFeedItems < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DELETE FROM feed_items
      WHERE id NOT IN (
        SELECT MIN(id) FROM feed_items
        GROUP BY feed_id, source_type, source_id
      )
    SQL
    add_index :feed_items, [:feed_id, :source_type, :source_id], unique: true, name: "index_feed_items_uniqueness"
  end

  def down
    remove_index :feed_items, name: "index_feed_items_uniqueness"
  end
end
