class MakeApiKeyNullableInApiConfigs < ActiveRecord::Migration[7.1]
  def change
    # Torna a coluna api_key nullable (permite NULL)
    change_column_null :api_configs, :api_key, true

    # Torna llm_model nullable também
    change_column_null :api_configs, :llm_model, true
  end
end