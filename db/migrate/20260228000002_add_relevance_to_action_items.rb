class AddRelevanceToActionItems < ActiveRecord::Migration[8.0]
  def change
    add_column :action_items, :relevance, :text, default: "direct", null: false
  end
end
