import { defineStore } from 'pinia'
import axios from 'axios'

// URL base da API Rails
// Ajuste conforme o ambiente

const API_BASE_URL = 'http://localhost:3000'

export const useAuthStore = defineStore('auth', {
    // state: dados que serão armazenados sobre o usuário logado
    state: () => ({
        user: null, // {user_id: number, name: string}
        token: null // Token JWT para autenticação
    }),

    // actions: funções que serão usadas para alterar o estado
    actions: {
        // Função de login: recebe o nome, chama o backend e guarda o usuário
        async login(name) {
            // Faz uma req POST para /sessions, com "name" no body
            const response = await axios.post(`${API_BASE_URL}/sessions`, { name })
        
            // O backend retorna {user_id, name}
            this.user = {
                id: response.data.user_id,
                name: response.data.name,
            }

            // Guarda o token JWT
            this.token = response.data.token;

            // Salvar no localStorage para assim manter o login mesmo após recarregar a página
            localStorage.setItem('chat_user', JSON.stringify(this.user))
            localStorage.setItem('chat_token', this.token)

            // Configura o token no axios para todas as requisições futuras
            this.setupAxiosInterceptor()
        },

        // Carrega o usuário do localStorage
        loadFromStorage() {
            const storedUser = localStorage.getItem('chat_user')
            const storedToken = localStorage.getItem('chat_token')
            
            if (storedUser && storedToken) {
                this.user = JSON.parse(storedUser)
                this.token = storedToken
                // Configura o interceptor do axios
                this.setupAxiosInterceptor()
            }
        },

        // Configura o interceptor do axios para enviar o token em todas as requisições
        setupAxiosInterceptor() {
            // Interceptor de requisição: adiciona o token no header Authorization
            axios.interceptors.request.use(
            (config) => {
                // Se tem um token, adiciona no header Authorization
                if (this.token) {
                config.headers.Authorization = `Bearer ${this.token}`
                }
                return config
            },
            (error) => {
                return Promise.reject(error)
            }
            )
    
            // Interceptor de resposta: trata erros de autenticação
            axios.interceptors.response.use(
            (response) => response,
            (error) => {
                // Se receber erro 401 (não autorizado), faz logout
                if (error.response?.status === 401) {
                this.logout()
                // Redireciona para login (precisa importar router aqui se necessário)
                window.location.href = '/login'
                }
                return Promise.reject(error)
            }
            )
        },

        // Função de logout: remove usuário, token e limpa localStorage
        logout() {
            this.user = null
            this.token = null
            localStorage.removeItem('chat_user')
            localStorage.removeItem('chat_token')
            
            // Remove o interceptor do axios
            axios.interceptors.request.clear()
            axios.interceptors.response.clear()
        },
    
        // Verifica se o usuário está autenticado
        isAuthenticated() {
            return !!this.token && !!this.user
        }
    }
})