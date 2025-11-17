class User < ApplicationRecord
    # Inclui o concern JwtToken para adicionar o método generate_jwt_token
    include JwtToken

    # Validações (opcional, mas recomendado)
    validates :name, presence: true, uniqueness: { case_sensitive: false }
end
