class CreateSupportTopicsAndConversationLink < ActiveRecord::Migration[7.1]
  def change
    create_table :support_topics do |t|
      t.integer :account_id, null: false
      t.string :name, null: false
      t.string :normalized_name, null: false

      t.timestamps
    end

    add_index :support_topics, [:account_id, :normalized_name], unique: true
    add_foreign_key :support_topics, :accounts

    add_reference :conversations, :support_topic, foreign_key: true, index: true
  end
end
