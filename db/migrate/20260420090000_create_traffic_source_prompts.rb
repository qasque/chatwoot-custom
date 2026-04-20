class CreateTrafficSourcePrompts < ActiveRecord::Migration[7.1]
  def change
    create_table :traffic_source_prompts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.text :source_id, null: false
      t.string :file_name, null: false
      t.text :prompt_text, null: false

      t.timestamps
    end

    add_index :traffic_source_prompts, [:inbox_id, :source_id], unique: true
    add_index :traffic_source_prompts, :source_id
  end
end
