class AddPriorityAndInteractionDescriptionToSlackChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :slack_channels, :priority, :integer, default: 3, null: false
    add_column :slack_channels, :interaction_description, :text
  end
end
