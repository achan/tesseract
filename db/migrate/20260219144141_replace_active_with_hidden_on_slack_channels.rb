class ReplaceActiveWithHiddenOnSlackChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :slack_channels, :hidden, :boolean, default: false, null: false
    remove_column :slack_channels, :active, :boolean, default: true, null: false
  end
end
