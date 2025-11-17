class ApplicationController < ActionController::API
    # Inclui o concern de autenticação JWT
    include JwtAuthenticatable
end
