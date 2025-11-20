import { defineStore } from 'pinia'
import axios from 'axios'

// URL base da API Rails
const API_BASE_URL = 'http://localhost:3000'

export const useApiConfigStore = defineStore('apiConfig', {
  state: () => ({
    config: null, // Configuração atual { id, llm_model, has_api_key }
    models: [], // Lista de modelos disponíveis
    loading: false, // Estado de carregamento
    error: null, // Mensagem de erro
    saving: false // Estado de salvamento
  }),

  actions: {
    // Busca a configuração atual do sistema
    async fetchConfig() {
      this.loading = true
      this.error = null

      try {
        const response = await axios.get(`${API_BASE_URL}/api_config`)
        this.config = response.data
        return response.data
      } catch (error) {
        console.error('Erro ao buscar configuração:', error)
        this.error = error.response?.data?.error || 'Erro ao carregar configuração'
        throw error
      } finally {
        this.loading = false
      }
    },

    // Salva ou atualiza a configuração (API key e modelo)
    async saveConfig(apiKey, llmModel) {
      this.saving = true
      this.error = null

      try {
        const response = await axios.post(`${API_BASE_URL}/api_config`, {
          api_key: apiKey,
          llm_model: llmModel
        })
        
        // Atualiza a configuração local
        this.config = {
          id: response.data.id,
          llm_model: response.data.llm_model,
          has_api_key: response.data.has_api_key
        }
        
        return response.data
      } catch (error) {
        console.error('Erro ao salvar configuração:', error)
        this.error = error.response?.data?.errors?.join(', ') || 'Erro ao salvar configuração'
        throw error
      } finally {
        this.saving = false
      }
    },
    // Atualiza apenas o modelo (sem precisar enviar API key novamente)
    async updateModel(llmModel) {
        this.saving = true
        this.error = null

        try {
        const response = await axios.patch(`${API_BASE_URL}/api_config`, {
            llm_model: llmModel
        })
        
        // Atualiza a configuração local
        if (this.config) {
            this.config.llm_model = response.data.llm_model
        } else {
            this.config = {
            id: response.data.id,
            llm_model: response.data.llm_model,
            has_api_key: response.data.has_api_key
            }
        }
        
        return response.data
        } catch (error) {
        console.error('Erro ao atualizar modelo:', error)
        this.error = error.response?.data?.errors?.join(', ') || 'Erro ao atualizar modelo'
        throw error
        } finally {
        this.saving = false
        }
    },

    // Lista os modelos disponíveis da OpenAI
    async fetchModels() {
        this.loading = true
        this.error = null

        try {
            const response = await axios.get(`${API_BASE_URL}/api_config/models`)
            this.models = response.data.models || []
            return this.models
        } catch (error) {
            console.error('Erro ao buscar modelos:', error)
            
            // Verifica se o erro indica que precisa redefinir a API key
            if (error.response?.data?.needs_reset) {
            this.error = error.response.data.error || 'API key não pode ser descriptografada. Por favor, redefina a API key.'
            } else {
            this.error = error.response?.data?.error || 'Erro ao carregar modelos'
            }
            
            throw error
        } finally {
            this.loading = false
        }
    }
  },

  getters: {
    // Verifica se há API key configurada
    hasApiKey: (state) => {
      return state.config?.has_api_key || false
    },

    // Retorna o modelo atual
    currentModel: (state) => {
      return state.config?.llm_model || null
    }
  }
})