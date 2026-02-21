class AddArchivedAtToActionItems < ActiveRecord::Migration[8.0]
  def change
    add_column :action_items, :archived_at, :datetime
    add_index :action_items, :archived_at
  end
end
