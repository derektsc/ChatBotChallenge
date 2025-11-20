class MessagesController < ApplicationController
    # GET /rooms/:room_id/messages - Lista todas as mensagens de uma sala
    def index
        # Busca a sala pelo ID
        room = Room.find(params[:room_id])

        # Busca todas as mensagens da sala, ordenadas por data de criação (mais antigas primeiro)
        messages = room.messages.includes(:user).order(created_at: :asc)

        # Retorna as mensagens em formato JSON
        render json: {
        room: {
            id: room.id,
            title: room.title,
            channel_name: room.channel_name,
            status: room.status
        },
        messages: messages.map { |message| format_message(message) }
        }, status: :ok

    rescue ActiveRecord::RecordNotFound
        render json: {
        error: 'Sala não encontrada'
        }, status: :not_found
    end

    # POST /rooms/:room_id/messages - Cria uma nova mensagem
    def create
        # Busca a sala pelo ID
        room = Room.find(params[:room_id])

        # Pega o conteúdo da mensagem do body da requisição
        content = params.require(:content).strip

        # Validação: não permite mensagem vazia
        if content.empty?
        render json: {
            errors: ['O conteúdo da mensagem não pode estar vazio']
        }, status: :unprocessable_entity
        return
        end

        # Cria a mensagem associada ao usuário atual e à sala
        message = room.messages.build(
        content: content,
        user: current_user
        )

        if message.save
        # Formata a mensagem para enviar via ActionCable
        message_data = format_message(message)
        
        # Faz broadcast da mensagem para todos os clientes conectados à sala
        # Isso permite que todos vejam a mensagem em tempo real
        ActionCable.server.broadcast(
            "room_#{room.id}",
            {
            type: 'new_message',
            message: message_data
            }
        )
        
        # Atualiza o contador de mensagens da sala
        # Isso será usado para mostrar notificações
        ActionCable.server.broadcast(
            "rooms",
            {
            type: 'room_message_count_updated',
            room_id: room.id,
            messages_count: room.messages.count
            }
        )

        # Detecta se a mensagem contém "@bot" e gera resposta automática
        if content.downcase.include?('@bot')
            # Processa a resposta do bot em background (não bloqueia a resposta)
            # Isso evita que o usuário tenha que esperar a resposta da OpenAI
            ProcessBotResponseJob.perform_later(room.id, content, current_user.id)
        end

        # Retorna a mensagem criada
        render json: message_data, status: :created
        else
        # Se houve erro de validação, retorna os erros
        render json: {
            errors: message.errors.full_messages
        }, status: :unprocessable_entity
        end

    rescue ActiveRecord::RecordNotFound
        render json: {
        error: 'Sala não encontrada'
        }, status: :not_found
    end

    private

    # Método helper para formatar os dados da mensagem
    def format_message(message)
        {
        id: message.id,
        content: message.content,
        user: {
            id: message.user.id,
            name: message.user.name
        },
        room_id: message.room_id,
        created_at: message.created_at,
        updated_at: message.updated_at
        }
    end
end