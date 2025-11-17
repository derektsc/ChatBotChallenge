# Channel para broadcast de eventos relacionados a salas
# Quando uma sala é criada, atualizada ou excluída, todos os usuários conectados recebem a atualização

module ApplicationCable
  class RoomsChannel < Channel
    # Método chamado quando um usuário se inscreve no channel
    def subscribed
      # Todos os usuários se inscrevem no mesmo stream "rooms"
      # Isso permite que todos recebam atualizações sobre salas
      stream_from "rooms"
    end

    # Método chamado quando um usuário se desinscreve
    def unsubscribed
      # Qualquer limpeza necessária pode ser feita aqui
    end
  end
end