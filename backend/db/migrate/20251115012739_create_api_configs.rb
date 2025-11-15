class CreateApiConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :api_configs do |t|
      t.string :api_key, null: false
      t.string :llm_model, null: false

      t.timestamps
    end
  end
end