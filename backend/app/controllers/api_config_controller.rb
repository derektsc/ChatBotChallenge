# backend/app/controllers/api_config_controller.rb
class ApiConfigController < ApplicationController
  
    # URL base da API da OpenAI
    OPENAI_BASE_URL = 'https://api.openai.com/v1'
  
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
          # Faz requisição direta para validar a API key
          unless validate_openai_api_key(api_key)
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
        # Lista os modelos diretamente usando Faraday
      models = list_openai_models(api_config.api_key)

      # Filtra apenas os modelos de chat (gpt-*, o1-*, claude-*, etc)
      # Remove modelos antigos como davinci-002 que não são para chat
      chat_models = models.select do |m|
        m.start_with?('gpt-') || 
        m.start_with?('o1-') || 
        m.start_with?('claude-') ||
        m.include?('chat') ||
        m.include?('turbo')
      end
      
      # Se não encontrou modelos de chat, retorna todos os modelos
      # (pode ser que a API key não tenha acesso a modelos de chat)
      chat_models = models if chat_models.empty?
      
      Rails.logger.info "Modelos carregados: #{models.count} total, #{chat_models.count} de chat"
      Rails.logger.info "Modelos encontrados: #{chat_models.inspect}"

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
  
    private
  
    # Valida a API key da OpenAI fazendo uma requisição de teste
    def validate_openai_api_key(api_key)
      # Faz uma requisição GET para /v1/models para validar a API key
      response = faraday_client.get('models') do |req|
        req.headers['Authorization'] = "Bearer #{api_key}"
      end
  
      # Se a requisição retornar 200, a API key é válida
      response.status == 200
    rescue Faraday::Error => e
      # Se houver erro de conexão, retorna false
      Rails.logger.error "Erro ao validar API key: #{e.message}"
      false
    end
  
    # Lista os modelos disponíveis da OpenAI
    def list_openai_models(api_key)
      # Faz uma requisição GET para /v1/models
      response = faraday_client.get('models') do |req|
        req.headers['Authorization'] = "Bearer #{api_key}"
      end
  
      # Verifica se a requisição foi bem sucedida
      if response.status == 200
        # Extrai os dados dos modelos da resposta
        data = JSON.parse(response.body)
        # Retorna apenas os Ids dos modelos (ex: gpt-4, gpt-3.5-turbo, etc)
        data['data'].map { |model| model['id'] }
      else
        # Se houver erro, lança uma exceção com mensagem de erro
        error_message = JSON.parse(response.body)['error']['message'] rescue "Erro desconhecido ao listar modelos"
        raise StandardError, "Erro ao listar modelos: #{error_message}"
      end
    rescue Faraday::Error => e
      # Trata erros de conexão (API Offline, timeout, etc)
      raise StandardError, "Erro ao conectar com a API OpenAI: #{e.message}"
    end
  
    # Cria e configura o cliente HTTP (Faraday) para fazer requisições HTTP
    # Faraday é uma gem que facilita fazer requisições HTTP
    def faraday_client
      @faraday_client ||= Faraday.new(url: OPENAI_BASE_URL) do |conn|
        # Configura timeout de 30 segundos
        conn.options.timeout = 30
        # Usa o adaptador padrão (net/http)
        conn.adapter Faraday.default_adapter
      end
    end
  end