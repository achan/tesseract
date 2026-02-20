class ChangeActionableDefaultOnSlackChannels < ActiveRecord::Migration[8.0]
  def change
    change_column_default :slack_channels, :actionable, from: false, to: true
  end
end
