class RoomsController < ApplicationController

    # GET /rooms - Lista todas as salas abertas
    def index
        # Busca TODAS as salas, ordenadas por status (abertas primeiro) e data
        all_rooms = Room.order(status: :asc, created_at: :desc)

        # Retorna as salas em formato JSON, separadas por status
        render json: {
        open_rooms: all_rooms.select { |r| r.status == 'open' }.map { |room| format_room(room) },
        closed_rooms: all_rooms.select { |r| r.status == 'closed' }.map { |room| format_room(room) }
        }, status: :ok
    end

    # POST /rooms - Criar uma nova sala
    def create
        # Pega o titulo da sala no body da requisição
        title = params.require(:title).strip

        # Cria uma nova sala com status "open"
        # O channel_name será gerado automaticamente pelo callback do modelo
        room = Room.new(title: title, status: 'open')

        if room.save
            # Faz broadcast da nova sala para todos os usuários conectados via ActionCable
            # Isso permite que a sala apareça em tempo real para todos, sem precisar recarregar a página
            ActionCable.server.broadcast(
                "rooms",
                {
                type: "room_created",
                room: format_room(room)
                }
            )

            # Se salvou com sucesso, retorna os dados da sala criada
            render json: format_room(room), status: :created
        else
            #Se houver erro de validação retorna o erro
            render json: {
                errors: room.errors.full_messages
            }, status: :unprocessable_entity
        end
    end

    # PATCH /rooms/:id/close - Marca uma sala como "atendimento concluído"
    # NÃO exclui a sala, apenas muda o status para "closed"
    def close
        # Busca a sala pelo ID
        room = Room.find(params[:id])

        # Marca como "closed" (concluída)
        # Isso preserva o histórico de mensagens
        room.update(status: 'closed')

        # Faz broadcast da atualização
        ActionCable.server.broadcast(
            "rooms",
            {
            type: "room_closed",
            room: format_room(room)
            }
        )

        # Retorna sucesso
        render json: {
        message: 'Sala marcada como atendimento concluído',
        room: format_room(room)
        }, status: :ok

    rescue ActiveRecord::RecordNotFound
        # Se a sala não foi encontrada, retorna erro 404
        render json: {
        error: 'Sala não encontrada'
        }, status: :not_found
    end

    # DELETE /rooms/:id - Exclui FISICAMENTE uma sala do banco de dados
    # ATENÇÃO: Isso também exclui todas as mensagens relacionadas (dependent: :destroy)
    def destroy
        # Busca a sala pelo ID
        room = Room.find(params[:id])
        room_id = room.id
        # Exclui a sala fisicamente do banco
        # Como o modelo tem dependent: :destroy, todas as mensagens também serão excluídas
        room.destroy

        # Faz broadcast da exclusão
        ActionCable.server.broadcast(
            "rooms",
            {
            type: "room_deleted",
            room_id: room_id
            }
        )

        # Retorna sucesso
        render json: {
        message: 'Sala excluída permanentemente'
        }, status: :ok

    rescue ActiveRecord::RecordNotFound
        # Se a sala não foi encontrada, retorna erro 404
        render json: {
        error: 'Sala não encontrada'
        }, status: :not_found
    end

    # GET /rooms/:id - Mostra os detalhes de uma sala especifica
    def show
        #Busca a sala pelo ID
        room = Room.find(params[:id])

        # Retorna os dados da sala
        render json: format_room(room), status: :ok
    rescue ActiveRecord::RecordNotFound
        render json: {
            error: 'Sala não encontrada'
        }, status: :not_found
    end

    private

    # Método helper para formatar os dados da sala
    # Evita repetição de código
    def format_room(room)
        {
        id: room.id,
        title: room.title,
        channel_name: room.channel_name,
        status: room.status,
        created_at: room.created_at,
        updated_at: room.updated_at,
        messages_count: room.messages.count
        }
    end
end