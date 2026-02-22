class CreateProfiles < ActiveRecord::Migration[8.0]
  def up
    create_table :profiles do |t|
      t.text :name, null: false
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end

    add_reference :workspaces, :profile, foreign_key: true

    # Create a profile for each existing workspace based on team_name
    execute <<~SQL
      INSERT INTO profiles (name, enabled, created_at, updated_at)
      SELECT team_name, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM workspaces
    SQL

    execute <<~SQL
      UPDATE workspaces
      SET profile_id = (
        SELECT profiles.id FROM profiles
        WHERE profiles.name = workspaces.team_name
        LIMIT 1
      )
    SQL

    change_column_null :workspaces, :profile_id, false
  end

  def down
    remove_reference :workspaces, :profile
    drop_table :profiles
  end
end
