class CreateOverviews < ActiveRecord::Migration[8.0]
  def change
    create_table :overviews do |t|
      t.text :body, null: false
      t.text :model_used

      t.timestamps
    end
  end
end
