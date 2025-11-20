# backend/app/controllers/api_config_controller.rb
require_dependency 'openai_service'

class ApiConfigController < ApplicationController
  # Este controller PRECISA de autenticação JWT
  # O método authenticate_user! será chamado automaticamente

  # GET /api_config - Retorna a configuração atual do sistema
  def show
    # Busca ou cria a configuração (sempre existe apenas uma)
    api_config = ApiConfig.current

    # Verifica se há API key configurada (valor bruto, sem criptografia)
    has_key = api_config.api_key.present? && !api_config.api_key.strip.empty?

    # Retorna os dados da configuração
    # NÃO retorna a API key por segurança
    render json: {
      id: api_config.id,
      llm_model: api_config.llm_model,
      has_api_key: has_key,
      created_at: api_config.created_at,
      updated_at: api_config.updated_at
    }, status: :ok
  end

  # POST /api_config - Salva ou atualiza a configuração
  def create
    # Busca ou cria a configuração atual
    api_config = ApiConfig.current

    # Pega os parâmetros do body da requisição
    api_key = params[:api_key]&.strip
    llm_model = params[:llm_model]&.strip

    # Validações: API key é obrigatória apenas se estiver sendo enviada
    # Modelo é opcional (pode ser salvo depois)
    errors = []
    
    # Se está tentando salvar API key, valida ela
    if api_key.present?
      errors << 'API key é obrigatória' if api_key.blank?
    end

    # Se está tentando salvar modelo, valida ele
    if llm_model.present?
      errors << 'Modelo LLM é obrigatório' if llm_model.blank?
    end

    # Se não está enviando nem API key nem modelo, retorna erro
    if api_key.blank? && llm_model.blank?
      errors << 'É necessário enviar pelo menos a API key ou o modelo'
    end

    if errors.any?
      render json: { errors: errors }, status: :unprocessable_entity
      return
    end

    # Atualiza a API key se foi fornecida
    if api_key.present?
      # Valida a API key fazendo uma requisição de teste à OpenAI
      begin
        openai_service = OpenaiService.new(api_key)
        
        unless openai_service.validate_api_key
          render json: { errors: ['API key inválida. Verifique se a chave está correta.'] }, status: :unprocessable_entity
          return
        end
        
        # Se a validação passou, atualiza a API key (valor bruto, sem criptografia)
        api_config.api_key = api_key
        Rails.logger.info "API key validada e será salva"
      rescue StandardError => e
        # Se houver erro ao validar (API offline, etc.), retorna erro
        Rails.logger.error "Erro ao validar API key: #{e.message}"
        render json: { errors: ["Erro ao validar API key: #{e.message}"] }, status: :unprocessable_entity
        return
      end
    end

    # Atualiza o modelo se foi fornecido
    if llm_model.present?
      api_config.llm_model = llm_model
    end

    # Se tudo estiver ok, salva a configuração
    if api_config.save
      # Verifica se há API key após salvar
      has_key = api_config.api_key.present? && !api_config.api_key.strip.empty?
      
      render json: {
        id: api_config.id,
        llm_model: api_config.llm_model,
        has_api_key: has_key,
        message: 'Configuração salva com sucesso!'
      }, status: :ok
    else
      render json: {
        errors: api_config.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH /api_config - Atualiza apenas o modelo (sem validar API key novamente)
  def update
    # Busca a configuração atual
    api_config = ApiConfig.current

    # Pega o modelo do body da requisição
    llm_model = params[:llm_model]&.strip

    # Validação
    if llm_model.blank?
      render json: { errors: ['Modelo LLM é obrigatório'] }, status: :unprocessable_entity
      return
    end

    # Atualiza apenas o modelo
    api_config.llm_model = llm_model

    if api_config.save
      # Verifica se há API key
      has_key = api_config.api_key.present? && !api_config.api_key.strip.empty?
      
      render json: {
        id: api_config.id,
        llm_model: api_config.llm_model,
        has_api_key: has_key,
        message: 'Modelo atualizado com sucesso!'
      }, status: :ok
    else
      render json: {
        errors: api_config.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api_config/models - Lista os modelos disponíveis da OpenAI
  def models
    # Busca a configuração atual
    api_config = ApiConfig.current

    # Verifica se há API key configurada (valor bruto, sem criptografia)
    unless api_config.api_key.present? && !api_config.api_key.strip.empty?
      Rails.logger.warn "Tentativa de listar modelos sem API key configurada"
      render json: {
        error: 'API key não configurada. Configure a API key primeiro.'
      }, status: :unprocessable_entity
      return
    end

    begin
      # Cria o service e lista os modelos
      # Usa a API key diretamente do banco (valor bruto)
      openai_service = OpenaiService.new(api_config.api_key)
      models = openai_service.list_models

      # Filtra apenas os modelos de chat (gpt-*)
      chat_models = models.select { |m| m.start_with?('gpt-') }
      
      Rails.logger.info "Modelos carregados com sucesso: #{chat_models.count} modelos encontrados"

      render json: {
        models: chat_models
      }, status: :ok
    rescue StandardError => e
      # Se houver erro, retorna mensagem de erro
      Rails.logger.error "Erro ao listar modelos da OpenAI: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        error: "Erro ao listar modelos: #{e.message}"
      }, status: :internal_server_error
    end
  end
end