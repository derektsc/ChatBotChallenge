# Concern que será incluído em controllers que precisam de autenticação JWT
# Um "concern" é uma forma de compartilhar código entre controllers no Rails

module JwtAuthenticatable
    extend ActiveSupport::Concern

    # Método que será chamado antes das ações do controller
    # Verifica se o token JWT é válido e identifica o usuário
    included do
        before_action :authenticate_user!
    end

    private

    # Método principal de autenticação
    # Extrai o token do header Authorization e valida
    def authenticate_user!
        token = extract_token_from_header

        if token.nil?
        render json: { error: 'Token não fornecido' }, status: :unauthorized
        return
        end

        begin
        # Decodifica e valida o token JWT
        decoded_token = decode_token(token)
        
        # Busca o usuário pelo ID que está dentro do token
        @current_user = User.find(decoded_token['user_id'])
        
        rescue JWT::DecodeError, JWT::ExpiredSignature => e
        # Token inválido ou expirado
        render json: { error: 'Token inválido ou expirado' }, status: :unauthorized
        rescue ActiveRecord::RecordNotFound
        # Usuário não encontrado no banco
        render json: { error: 'Usuário não encontrado' }, status: :unauthorized
        end
    end

    # Extrai o token do header Authorization
    # Formato esperado: "Authorization: Bearer <token>"
    def extract_token_from_header
        auth_header = request.headers['Authorization']
        return nil unless auth_header

        # Remove o prefixo "Bearer " e retorna apenas o token
        auth_header.split(' ').last if auth_header.start_with?('Bearer ')
    end

    # Decodifica o token JWT usando a secret key
    def decode_token(token)
        # A secret key deve ser uma string segura (em produção, use variável de ambiente)
        secret_key = Rails.application.credentials.secret_key_base || 'development_secret_key_change_in_production'
        
        # Decodifica o token e retorna o payload (dados dentro do token)
        JWT.decode(token, secret_key, true, { algorithm: 'HS256' })[0]
    end

    # Método helper para acessar o usuário atual em qualquer controller
    def current_user
        @current_user
    end
end