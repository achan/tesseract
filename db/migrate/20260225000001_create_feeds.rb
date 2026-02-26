class CreateFeeds < ActiveRecord::Migration[8.0]
  def change
    create_table :feeds do |t|
      t.text :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :feeds, :position
  end
end
