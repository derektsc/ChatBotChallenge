class CreateRooms < ActiveRecord::Migration[7.1]
  def change
    create_table :rooms do |t|
      t.string :channel_name
      t.string :title, null: false
      t.string :status, default: "open", null: false

      t.timestamps
    end
    add_index :rooms, :channel_name
  end
end