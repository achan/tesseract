class AddActionableToSlackChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :slack_channels, :actionable, :boolean, default: false, null: false

    reversible do |dir|
      dir.up do
        execute "UPDATE slack_channels SET actionable = 1 WHERE hidden = 0"
      end
    end
  end
end
