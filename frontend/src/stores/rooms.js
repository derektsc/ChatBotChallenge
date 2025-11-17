import { defineStore } from 'pinia'
import axios from 'axios'
import { useAuthStore } from './auth'

// URL base API Rails
const API_BASE_URL = 'http://localhost:3000'

export const useRoomsStore = defineStore('rooms', {
    state: () => ({
        rooms: [], // Lista de salas
        currentRoom: null, // Sala atual selecionada
        loading: false, // estado de carregamento
        error: null // mensagem de erro
    }),

    actions: {
        // Busca todas as salas abertas do backend
        async fetchRooms() {
            this.loading = true
            this.error = null

            try {
                // O Token JWT será enviado automaticamente pelo interceptor do axios configurado no auth store
                const response = await axios.get(`${API_BASE_URL}/rooms`)

                // Atualiza a lista de salas com os dados retornados
                // O backend retorna { open_rooms: [...], closed_rooms: [...] }
                this.rooms = [
                    ...(response.data.open_rooms || []),
                    ...(response.data.closed_rooms || [])
                ]
            } catch (error) {
                console.error('Erro ao buscar salas:', error)
                this.error = error.response?.data?.error || 'Erro ao carregar salas'
                throw error
            } finally {
                this.loading = false
            }
        },

        // Cria uma nova sala
        async createRoom(title) {
            this.loading = true
            this.error = null

            try {
                const response = await axios.post(`${API_BASE_URL}/rooms`, {
                    title: title.trim()
                })

                return response.data
            } catch (error) {
                console.error('Erro ao criar sala:', error)
                this.error = error.response?.data?.errors?.join(', ') || 'Erro ao criar sala'
                throw error
            } finally{
                this.loading = false
            }
        },

        // Marca uma sala como "atendimento concluído" (fecha a sala, mas não exclui)
        async closeRoom(roomId) {
            this.loading = true
            this.error = null
    
            try {
            await axios.patch(`${API_BASE_URL}/rooms/${roomId}/close`)
            
            // Atualiza o status da sala na lista local
            const room = this.rooms.find(r => r.id === roomId)
            if (room) {
                room.status = 'closed'
            }
            
            // Se a sala fechada era a atual, limpa a seleção
            if (this.currentRoom?.id === roomId) {
                this.currentRoom = null
            }
            } catch (error) {
            console.error('Erro ao fechar sala:', error)
            this.error = error.response?.data?.error || 'Erro ao fechar sala'
            throw error
            } finally {
            this.loading = false
            }
        },
        // Exclui FISICAMENTE uma sala do banco de dados
        async deleteRoom(roomId) {
            this.loading = true
            this.error = null
    
            try {
            await axios.delete(`${API_BASE_URL}/rooms/${roomId}`)
            
            // Remove a sala da lista local
            this.rooms = this.rooms.filter(room => room.id !== roomId)
            
            // Se a sala excluída era a atual, limpa a seleção
            if (this.currentRoom?.id === roomId) {
                this.currentRoom = null
            }
            } catch (error) {
            console.error('Erro ao excluir sala:', error)
            this.error = error.response?.data?.error || 'Erro ao excluir sala'
            throw error
            } finally {
            this.loading = false
            }
        },

        //Define a sala atual (quano usuario clicar na sala)
        setCurrentRoom(room) {
            this.currentRoom = room
        },

        // Limpa a sala atual
        clearCurrentRoom(){
            this.currentRoom = null
        }
    },

    getters: {
        //Retorna apenas salas abertas
        openRooms: (state) => {
            return state.rooms.filter(room => room.status === 'open')
        },

        // Retorna apenas salas fechadas (concluídas)
        closedRooms: (state) => {
            return state.rooms.filter(room => room.status === 'closed')
        },
  
        // Retorna o número total de salas
        totalRooms: (state) => {
            return state.rooms.length
        }
    }
})