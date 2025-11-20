# Job que processa a resposta do bot em background

class ProcessBotResponseJob < ApplicationJob
    queue_as :default

    # URL base da API da OpenAI
    OPENAI_BASE_URL = 'https://api.openai.com/v1'

    def perform(room_id, user_message, user_id)
        # Busca a sala
        room = Room.find(room_id)
        
        # Busca a configuração da OpenAI
        api_config = ApiConfig.current

        # Verifica se há API key configurada (valor bruto, sem criptografia)
        unless api_config&.api_key.present?
        Rails.logger.warn "API key não configurada. Bot não pode responder."
        return
        end

        # Verifica se há modelo configurado
        unless api_config.llm_model.present?
        Rails.logger.warn "Modelo LLM não configurado. Bot não pode responder."
        return
        end

        begin
        # Remove o "@bot" da mensagem para criar um prompt melhor
        prompt = user_message.gsub(/@bot/i, '').strip
        
        # Se o prompt estiver vazio após remover @bot, usa uma mensagem padrão
        prompt = "Olá! Como posso ajudar?" if prompt.blank?
        
        # Detecta o tipo de modelo e gera a resposta usando o endpoint correto
        bot_response = generate_openai_response(api_config.api_key, api_config.llm_model, prompt)
        
        # Busca ou cria um usuário "Bot" para as mensagens automáticas
        bot_user = User.find_or_create_by!(name: 'Bot')
        
        # Cria a mensagem do bot na sala
        bot_message = room.messages.create!(
            content: bot_response,
            user: bot_user
        )
        
        # Formata a mensagem para enviar via ActionCable
        message_data = {
            id: bot_message.id,
            content: bot_message.content,
            user: {
            id: bot_user.id,
            name: bot_user.name
            },
            room_id: bot_message.room_id,
            created_at: bot_message.created_at,
            updated_at: bot_message.updated_at
        }
        
        # Faz broadcast da mensagem do bot para todos os clientes conectados
        ActionCable.server.broadcast(
            "room_#{room.id}",
            {
            type: 'new_message',
            message: message_data
            }
        )
        
        # Atualiza o contador de mensagens
        ActionCable.server.broadcast(
            "rooms",
            {
            type: 'room_message_count_updated',
            room_id: room.id,
            messages_count: room.messages.count
            }
        )
        
        Rails.logger.info "Bot respondeu na sala #{room.id}"
        rescue StandardError => e
        # Se houver erro, loga mas não quebra o fluxo
        Rails.logger.error "Erro ao processar resposta do bot: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        end
    end

    private

    # Detecta se o modelo é de chat ou completion
    def is_chat_model?(model_name)
        # Modelos de chat: gpt-*, o1-*, claude-*, etc
        model_name.start_with?('gpt-') || 
        model_name.start_with?('o1-') || 
        model_name.start_with?('claude-') ||
        model_name.include?('chat') ||
        model_name.include?('turbo')
    end

    # Gera resposta usando o endpoint correto baseado no tipo de modelo
    def generate_openai_response(api_key, model, prompt)
        if is_chat_model?(model)
        # Usa o endpoint de chat completions
        generate_chat_completion(api_key, model, prompt)
        else
        # Usa o endpoint antigo de completions (para davinci-002, etc)
        generate_completion(api_key, model, prompt)
        end
    end

    # Gera resposta usando /v1/chat/completions (modelos de chat)
    def generate_chat_completion(api_key, model, prompt)
        response = faraday_client.post('chat/completions') do |req|
        req.headers['Authorization'] = "Bearer #{api_key}"
        req.headers['Content-Type'] = 'application/json'
        req.body = {
            model: model,
            messages: [
            {
                role: 'user',
                content: prompt
            }
            ],
            temperature: 0.7,
            max_tokens: 500
        }.to_json
        end

        if response.status == 200
        data = JSON.parse(response.body)
        data.dig('choices', 0, 'message', 'content')
        else
        error_data = JSON.parse(response.body) rescue {}
        error_message = error_data.dig('error', 'message') || 'Erro desconhecido'
        raise StandardError, "Erro ao gerar resposta: #{error_message}"
        end
    rescue Faraday::Error => e
        raise StandardError, "Erro ao conectar com a API OpenAI: #{e.message}"
    end

    # Gera resposta usando /v1/completions (modelos antigos como davinci-002)
    def generate_completion(api_key, model, prompt)
        response = faraday_client.post('completions') do |req|
        req.headers['Authorization'] = "Bearer #{api_key}"
        req.headers['Content-Type'] = 'application/json'
        req.body = {
            model: model,
            prompt: prompt,
            temperature: 0.7,
            max_tokens: 500
        }.to_json
        end

        if response.status == 200
        data = JSON.parse(response.body)
        data.dig('choices', 0, 'text')
        else
        error_data = JSON.parse(response.body) rescue {}
        error_message = error_data.dig('error', 'message') || 'Erro desconhecido'
        raise StandardError, "Erro ao gerar resposta: #{error_message}"
        end
    rescue Faraday::Error => e
        raise StandardError, "Erro ao conectar com a API OpenAI: #{e.message}"
    end

    # Cria e configura o cliente HTTP (Faraday)
    def faraday_client
        @faraday_client ||= Faraday.new(url: OPENAI_BASE_URL) do |conn|
        conn.options.timeout = 30
        conn.adapter Faraday.default_adapter
        end
    end
end