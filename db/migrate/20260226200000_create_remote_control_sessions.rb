class CreateRemoteControlSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :remote_control_sessions do |t|
      t.text :status, null: false, default: "starting"
      t.integer :pid
      t.text :session_url
      t.text :error_message
      t.timestamps
    end
  end
end
