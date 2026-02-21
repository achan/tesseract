class UpdateActionItemStatuses < ActiveRecord::Migration[8.0]
  def up
    # Rename existing statuses
    execute "UPDATE action_items SET status = 'untriaged' WHERE status = 'open'"
    execute "UPDATE action_items SET status = 'wontfix' WHERE status = 'dismissed'"

    # Update the default
    change_column_default :action_items, :status, from: "open", to: "untriaged"
  end

  def down
    execute "UPDATE action_items SET status = 'open' WHERE status IN ('untriaged', 'in_progress', 'backlog')"
    execute "UPDATE action_items SET status = 'dismissed' WHERE status = 'wontfix'"

    change_column_default :action_items, :status, from: "untriaged", to: "open"
  end
end
