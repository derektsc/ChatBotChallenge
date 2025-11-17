module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    # Método chamado quando um cliente tenta se conectar ao WebSocket
    def connect
      # Rejeita a conexão se não houver token
      reject_unauthorized_connection unless token.present?

      # Decodifica o token JWT para identificar o usuário
      decoded_token = decode_token(token)
      self.current_user = User.find(decoded_token['user_id'])
    rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
      # Se o token for inválido ou o usuário não existir, rejeita a conexão
      reject_unauthorized_connection
    end

    private

    # Extrai o token do header Authorization ou dos query params
    def token
      # Tenta pegar do header primeiro
      auth_header = request.headers['Authorization']
      if auth_header&.start_with?('Bearer ')
        return auth_header.split(' ').last
      end

      # Se não encontrar no header, tenta nos query params
      # O frontend pode passar o token como ?token=xxx
      request.params[:token]
    end

    # Decodifica o token JWT
    def decode_token(token)
      secret_key = Rails.application.credentials.secret_key_base || 'development_secret_key_change_in_production'
      JWT.decode(token, secret_key, true, { algorithm: 'HS256' })[0]
    end
  end
end