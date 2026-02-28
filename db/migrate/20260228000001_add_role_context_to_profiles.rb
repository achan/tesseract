class AddRoleContextToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :role_context, :text
  end
end
