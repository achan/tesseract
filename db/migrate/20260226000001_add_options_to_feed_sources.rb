class AddOptionsToFeedSources < ActiveRecord::Migration[8.0]
  def up
    add_column :feed_sources, :options, :json, default: {}, null: false

    execute <<~SQL
      UPDATE feed_sources
      SET options = '{"auto_include_new_channels": true}'
      WHERE source_type = 'Workspace'
    SQL
  end

  def down
    remove_column :feed_sources, :options
  end
end
