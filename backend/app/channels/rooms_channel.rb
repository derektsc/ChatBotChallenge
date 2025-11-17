# backend/app/channels/rooms_channel.rb
# Channel para broadcast de eventos relacionados a salas
# Quando uma sala é criada, atualizada ou excluída, todos os usuários conectados recebem a atualização

class RoomsChannel < ApplicationCable::Channel
  # Método chamado quando um usuário se inscreve no channel
  def subscribed
    Rails.logger.info "Usuário #{current_user.id} tentando se inscrever no RoomsChannel"
    Rails.logger.info "Params recebidos: #{params.inspect}"
    
    # O cliente pode se inscrever em uma sala específica
    # params[:room_id] vem do frontend quando faz subscribe
    if params[:room_id].present?
      room = Room.find_by(id: params[:room_id])
      if room
        # Cria um stream específico para esta sala
        stream_from "room_#{room.id}"
        Rails.logger.info "Usuário #{current_user.id} inscrito na sala #{room.id}"
      else
        Rails.logger.warn "Sala #{params[:room_id]} não encontrada"
      end
    else
      # Se não especificar room_id, se inscreve em todas as salas
      # Útil para receber notificações de novas salas
      stream_from "rooms"
      Rails.logger.info "Usuário #{current_user.id} inscrito no channel geral de salas"
    end
  end

  # Método chamado quando um usuário se desinscreve
  def unsubscribed
    Rails.logger.info "Usuário #{current_user.id} se desinscreveu do RoomsChannel"
  end
end