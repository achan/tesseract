class AddRoleContextToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :role_context, :text

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE profiles SET role_context = 'Principal developer and devops. Responsible for infrastructure, deployments, code reviews, and architecture decisions.'
        SQL
      end
    end
  end
end
