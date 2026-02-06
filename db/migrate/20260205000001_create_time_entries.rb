class CreateTimeEntries < ActiveRecord::Migration[8.2]
  def change
    create_table :time_entries, id: :uuid, if_not_exists: true do |t|
      t.uuid :account_id, null: false
      t.uuid :card_id, null: false
      t.uuid :creator_id, null: false
      t.integer :total_minutes, null: false
      t.date :date, null: false
      t.text :description

      t.timestamps

      t.index :account_id
      t.index :card_id
    end
  end
end
