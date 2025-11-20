# backend/app/models/api_config.rb
class ApiConfig < ApplicationRecord
  # API key é única para todos os usuários, não é necessário belongs_to :user
  # IMPORTANTE: API key será armazenada em texto plano no banco

  # Método para obter a configuração atual (singleton pattern)
  # Como só existe uma configuração no sistema, sempre retornamos a primeira
  def self.current
    first_or_initialize
  end

  # Método helper para verificar se há API key configurada
  # Verifica diretamente no banco se há dados
  def has_api_key?
    api_key.present? && !api_key.strip.empty?
  end
end