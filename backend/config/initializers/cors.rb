# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

# Rails.application.config.middleware.insert_before 0, Rack::Cors do
#   allow do
#     origins "example.com"
#
#     resource "*",
#       headers: :any,
#       methods: [:get, :post, :put, :patch, :delete, :options, :head]
#   end
# end

# Configuração de CORS para permitir requisições do frontend Vue
Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
        # Em desenvolvimento, permite qualquer origem
        # Em produção, deve especificar o domínio exato do frontend
        origins '*'  # Permite requisições de qualquer origem (apenas para desenvolvimento)
    
        resource '*',
            headers: :any,  # Permite qualquer header
            methods: [:get, :post, :put, :patch, :delete, :options, :head],  # Métodos HTTP permitidos
            credentials: false  # Não permite envio de cookies/credenciais
    end
end