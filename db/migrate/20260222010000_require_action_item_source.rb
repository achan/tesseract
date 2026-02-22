class RequireActionItemSource < ActiveRecord::Migration[8.0]
  def up
    # Assign existing sourceless action items to the Docovia profile
    docovia = Profile.find_by!(name: "Docovia")
    ActionItem.where(source_type: nil).update_all(source_type: "Profile", source_id: docovia.id)

    change_column_null :action_items, :source_type, false
    change_column_null :action_items, :source_id, false
  end

  def down
    change_column_null :action_items, :source_type, true
    change_column_null :action_items, :source_id, true
  end
end
