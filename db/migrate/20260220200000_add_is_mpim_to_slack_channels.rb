class AddIsMpimToSlackChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :slack_channels, :is_mpim, :boolean, default: false, null: false
  end
end
