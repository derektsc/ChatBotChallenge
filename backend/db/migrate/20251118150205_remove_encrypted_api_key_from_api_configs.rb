class RemoveEncryptedApiKeyFromApiConfigs < ActiveRecord::Migration[7.1]
  def change
    # Remove a coluna encrypted_api_key (não precisamos mais dela)
    remove_column :api_configs, :encrypted_api_key, :text, if_exists: true

    # Ajusta a coluna api_key para TEXT (armazenará dados criptografados maiores)
    change_column :api_configs, :api_key, :text, null: true
  end
end
