import { defineStore } from 'pinia'
import axios from 'axios'
import { useAuthStore } from './auth'

// URL base da API Rails
const API_BASE_URL = 'http://localhost:3000'

export const useMessagesStore = defineStore('messages', {
  state: () => ({
    messages: {}, // { roomId: [messages] } - mensagens por sala
    loading: false, // Estado de carregamento
    error: null, // Mensagem de erro
    sending: {}, // { roomId: boolean } - estado de envio por sala
    unreadCounts: {}, // { roomId: number } - contador de mensagens não lidas
    lastReadMessage: {} // { roomId: messageId } - última mensagem lida por sala
  }),

  actions: {
    // Busca todas as mensagens de uma sala
    async fetchMessages(roomId) {
      this.loading = true
      this.error = null

      try {
        const response = await axios.get(`${API_BASE_URL}/rooms/${roomId}/messages`)
        
        // Armazena as mensagens no objeto messages, usando roomId como chave
        this.messages[roomId] = response.data.messages || []
        
        // Marca todas as mensagens como lidas quando carrega
        if (this.messages[roomId].length > 0) {
          const lastMessage = this.messages[roomId][this.messages[roomId].length - 1]
          this.lastReadMessage[roomId] = lastMessage.id
          this.unreadCounts[roomId] = 0
        }
        
        return response.data
      } catch (error) {
        console.error('Erro ao buscar mensagens:', error)
        this.error = error.response?.data?.error || 'Erro ao carregar mensagens'
        throw error
      } finally {
        this.loading = false
      }
    },

    // Envia uma nova mensagem para uma sala
    async sendMessage(roomId, content) {
      this.sending[roomId] = true
      this.error = null

      try {
        const response = await axios.post(`${API_BASE_URL}/rooms/${roomId}/messages`, {
          content: content.trim()
        })
        
        // Adiciona a nova mensagem na lista de mensagens da sala
        if (!this.messages[roomId]) {
          this.messages[roomId] = []
        }
        this.messages[roomId].push(response.data)
        
        // Marca como lida já que o usuário enviou
        this.lastReadMessage[roomId] = response.data.id
        this.unreadCounts[roomId] = 0
        
        return response.data
      } catch (error) {
        console.error('Erro ao enviar mensagem:', error)
        this.error = error.response?.data?.errors?.join(', ') || 'Erro ao enviar mensagem'
        throw error
      } finally {
        this.sending[roomId] = false
      }
    },

    // Adiciona uma mensagem recebida via ActionCable
    addMessage(roomId, message) {
      if (!this.messages[roomId]) {
        this.messages[roomId] = []
      }
      
      // Verifica se a mensagem já não existe (evita duplicatas)
      const exists = this.messages[roomId].some(m => m.id === message.id)
      if (!exists) {
        this.messages[roomId].push(message)
        
        // Se a sala não está aberta ou a mensagem não é do usuário atual, incrementa contador
        // Isso será verificado no componente que usa o store
      }
    },

    // Marca mensagens como lidas
    markAsRead(roomId) {
      if (this.messages[roomId] && this.messages[roomId].length > 0) {
        const lastMessage = this.messages[roomId][this.messages[roomId].length - 1]
        this.lastReadMessage[roomId] = lastMessage.id
        this.unreadCounts[roomId] = 0
      }
    },

    // Incrementa contador de não lidas
    incrementUnread(roomId) {
      if (!this.unreadCounts[roomId]) {
        this.unreadCounts[roomId] = 0
      }
      this.unreadCounts[roomId]++
    },

    // Limpa as mensagens de uma sala
    clearMessages(roomId) {
      delete this.messages[roomId]
      delete this.unreadCounts[roomId]
      delete this.lastReadMessage[roomId]
    }
  },

  getters: {
    // Retorna as mensagens de uma sala específica
    getMessagesByRoom: (state) => {
      return (roomId) => {
        return state.messages[roomId] || []
      }
    },

    // Verifica se está enviando mensagem para uma sala
    isSending: (state) => {
      return (roomId) => {
        return state.sending[roomId] || false
      }
    },

    // Retorna o contador de mensagens não lidas de uma sala
    getUnreadCount: (state) => {
      return (roomId) => {
        return state.unreadCounts[roomId] || 0
      }
    }
  }
})