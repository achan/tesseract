class MakeActionItemDescriptionOptional < ActiveRecord::Migration[8.0]
  def change
    change_column_null :action_items, :description, true
  end
end
