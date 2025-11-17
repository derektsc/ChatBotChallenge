class SessionsController < ApplicationController
  # Este controller NÃO precisa de autenticação (é onde o usuário faz login)
  # Por isso desabilitamos a autenticação aqui
  skip_before_action :authenticate_user!

  # A ação create será chamada quanto o frontend fizer POST /sessions
  def create
    # Pego o param :name do body da requisição e uso require para garantir a existencia,
    # depois strip para remover espaços em branco.
    name = params.require(:name).strip

    # Encontra ou cria um usuário com esse nome, se já existir retorna usuário existente, se não
    # cria um novo.
    user = User.find_or_create_by!(name: name)

    # Gera o token JWT para o usuário
    token = user.generate_jwt_token

    # Retorna os dados do úsuario em JSON, dessa forma o frontend pode usar o id do usuário para
    # identificar o usuário logado.
    render json: {
      user_id: user.id,
      name: user.name,
      token: token # Token JWT para autenticação
    }, status: :created
  end
end
