# Concern para adicionar métodos relacionados a JWT no modelo User

module JwtToken
    extend ActiveSupport::Concern

    # Gera um token JWT para o usuário
    # O token contém o ID do usuário e uma data de expiração
    def generate_jwt_token
        # Payload: dados que serão armazenados dentro do token
        payload = {
            user_id: id,
            name: name,
            exp: 24.hours.from_now.to_i  # Token expira em 24 horas
        }

        # Secret key para assinar o token (em produção, usar variável de ambiente)
        secret_key = Rails.application.credentials.secret_key_base || 'development_secret_key_change_in_production'

        # Gera o token JWT usando o algoritmo HS256
        JWT.encode(payload, secret_key, 'HS256')
    end
end