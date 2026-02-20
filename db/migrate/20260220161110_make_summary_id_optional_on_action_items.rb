class MakeSummaryIdOptionalOnActionItems < ActiveRecord::Migration[8.0]
  def change
    change_column_null :action_items, :summary_id, true
    remove_foreign_key :action_items, :summaries
  end
end
