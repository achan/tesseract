class CreateSummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :summaries do |t|
      t.text :source_type
      t.integer :source_id
      t.datetime :period_start
      t.datetime :period_end
      t.text :summary_text
      t.text :model_used

      t.timestamps
    end

    add_index :summaries, [ :source_type, :source_id ]
  end
end
