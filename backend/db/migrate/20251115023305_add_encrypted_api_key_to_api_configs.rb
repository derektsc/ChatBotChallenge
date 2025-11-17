class AddEncryptedApiKeyToApiConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :api_configs, :encrypted_api_key, :text
  end
end
