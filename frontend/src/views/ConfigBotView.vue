<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useApiConfigStore } from '../stores/apiConfig'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const apiConfigStore = useApiConfigStore()
const authStore = useAuthStore()

// Estado do formulário
const apiKey = ref('')
const selectedModel = ref('')
const showApiKey = ref(false) // Para mostrar/ocultar a API key ao digitar
const isEditingApiKey = ref(false) // controla se está editando a API key

// Carrega configuração quando o componente monta
onMounted(async () => {
  // Verifica autenticação
  authStore.loadFromStorage()
  if (!authStore.isAuthenticated()) {
    router.push('/login')
    return
  }

  // Carrega a configuração atual
  try {
    await apiConfigStore.fetchConfig()
    
    // console.log('Config carregada:', apiConfigStore.config)
    // console.log('Has API Key:', apiConfigStore.hasApiKey)
    
    // Se já tem modelo configurado, seleciona ele
    if (apiConfigStore.currentModel) {
      selectedModel.value = apiConfigStore.currentModel
    }
    
    // Se já tem API key, tenta carregar os modelos
    if (apiConfigStore.hasApiKey) {
      // console.log('API key já configurada, carregando modelos...')
      await loadModels()
    }
  } catch (error) {
    // console.error('Erro ao carregar configuração:', error)
  }
})

// Carrega os modelos disponíveis
const loadModels = async () => {
  try {
    // console.log('Carregando modelos da OpenAI...')
    await apiConfigStore.fetchModels()
    // console.log('Modelos carregados:', apiConfigStore.models)
    
    // Se não tem modelo selecionado e há modelos disponíveis, seleciona o primeiro
    if (!selectedModel.value && apiConfigStore.models.length > 0) {
      selectedModel.value = apiConfigStore.models[0]
      // console.log('Modelo selecionado automaticamente:', selectedModel.value)
    }
  } catch (error) {
    // console.error('Erro ao carregar modelos:', error)
  }
}

// Função para salvar apenas o modelo (quando já tem API key)
const handleSave = async () => {
  if (!apiKey.value.trim()) {
    return
  }

  try {
    // Salva APENAS a API key (sem modelo)
    await apiConfigStore.saveConfig(apiKey.value.trim(), '')
    
    // Recarrega a configuração para atualizar o estado
    await apiConfigStore.fetchConfig()
    
    // Se salvou com sucesso E tem API key configurada, carrega os modelos
    if (apiConfigStore.hasApiKey) {
      // console.log('API key salva, carregando modelos...')
      await loadModels()
    }
    
    // Limpa o campo da API key por segurança
    apiKey.value = ''
    isEditingApiKey.value = false // Para de editar após salvar
  } catch (error) {
    // console.error('Erro ao salvar configuração:', error)
  }
}

// Função para iniciar edição da API key
const startEditingApiKey = () => {
  isEditingApiKey.value = true
  apiKey.value = '' // Limpa o campo para nova entrada
}

// Função para cancelar edição
const cancelEditingApiKey = () => {
  isEditingApiKey.value = false
  apiKey.value = ''
}

const handleSaveModel = async () => {
  if (!selectedModel.value) {
    return
  }

  try {
    // Atualiza apenas o modelo usando PATCH
    await apiConfigStore.updateModel(selectedModel.value)
    
    // Recarrega a configuração para atualizar o estado
    await apiConfigStore.fetchConfig()
    
    // Mostra feedback visual (opcional)
    // console.log('Modelo salvo com sucesso:', selectedModel.value)
  } catch (error) {
    // console.error('Erro ao salvar modelo:', error)
  }
}

// Computed para verificar se o modelo selecionado é de chat
const isChatModel = computed(() => {
  if (!selectedModel.value) return true
  
  const model = selectedModel.value.toLowerCase()
  return model.startsWith('gpt-') || 
         model.startsWith('o1-') || 
         model.startsWith('claude-') ||
         model.includes('chat') ||
         model.includes('turbo')
})

// Computed para verificar se pode salvar
const canSave = computed(() => {
  return apiKey.value.trim().length > 0
})

// Computed para verificar se pode selecionar modelo
const canSelectModel = computed(() => {
  return apiConfigStore.hasApiKey && apiConfigStore.models.length > 0
})
</script>

<template>
  <div>
    <!-- Barra superior -->
    <v-app-bar color="primary" prominent>
      <v-btn
        icon
        variant="text"
        @click="router.push('/rooms')"
        class="mr-2"
      >
        <v-icon>mdi-arrow-left</v-icon>
      </v-btn>

      <v-app-bar-title>
        <v-icon start>mdi-robot</v-icon>
        Configurar @Bot
      </v-app-bar-title>

      <v-spacer></v-spacer>
    </v-app-bar>

    <!-- Conteúdo principal -->
    <v-main>
      <v-container max-width="800" class="py-8">
        <!-- Card de configuração -->
        <v-card class="pa-6">
          <v-alert
                type="info"
                variant="tonal"
                class="mb-4"
                border="start"
                border-color="info"
              >
                
                <div>
                  <strong>Aviso Importante:</strong>
                  <br>
                  A API key será salva no banco de dados <strong>sem criptografia</strong>.
                  <br>
                  <span class="text-caption">
                    Esta não é uma boa prática para produção, mas foi implementada desta forma 
                    para facilitar a configuração neste projeto de teste/estudo.
                  </span>
                </div>
              </v-alert>

          <!-- Formulário de API Key -->
          <v-card variant="outlined" class="mb-6">
            <v-card-title class="text-subtitle-1">
              <v-icon start>mdi-key</v-icon>
              API Key da OpenAI
            </v-card-title>

            <v-card-text>
              <!-- Status da API key (quando já está configurada) -->
              <v-alert
                v-if="apiConfigStore.hasApiKey && !isEditingApiKey"
                type="success"
                variant="tonal"
                class="mb-4"
              >
                <v-icon start>mdi-check-circle</v-icon>
                <strong>API Key configurada com sucesso!</strong>
                <template v-slot:append>
                  <v-btn
                    size="small"
                    variant="text"
                    color="primary"
                    @click="startEditingApiKey"
                  >
                    <v-icon start size="small">mdi-pencil</v-icon>
                    Alterar
                  </v-btn>
                </template>
              </v-alert>

              <!-- Campo de input (sempre visível ou quando está editando) -->
              <v-text-field
                v-if="!apiConfigStore.hasApiKey || isEditingApiKey"
                v-model="apiKey"
                :type="showApiKey ? 'text' : 'password'"
                label="API Key"
                placeholder="sk-..."
                prepend-inner-icon="mdi-key-variant"
                variant="outlined"
                :append-inner-icon="showApiKey ? 'mdi-eye-off' : 'mdi-eye'"
                @click:append-inner="showApiKey = !showApiKey"
                :disabled="apiConfigStore.saving"
                hint="A API key será validada ao salvar"
                persistent-hint
                class="mb-2"
              ></v-text-field>

              <!-- Botões de ação -->
              <div v-if="!apiConfigStore.hasApiKey || isEditingApiKey">
                <v-btn
                  color="primary"
                  :loading="apiConfigStore.saving"
                  :disabled="!canSave"
                  @click="handleSave"
                  class="mr-2"
                >
                  <v-icon start>mdi-content-save</v-icon>
                  {{ isEditingApiKey ? 'Atualizar API Key' : 'Salvar API Key' }}
                </v-btn>

                <v-btn
                  v-if="isEditingApiKey"
                  variant="outlined"
                  @click="cancelEditingApiKey"
                  :disabled="apiConfigStore.saving"
                >
                  Cancelar
                </v-btn>
              </div>
            </v-card-text>
          </v-card>

          <!-- Seleção de Modelo -->
          <v-card variant="outlined">
            <v-card-title class="text-subtitle-1">
              <v-icon start>mdi-brain</v-icon>
              Modelo LLM
            </v-card-title>

            <v-card-text>
              <!-- Loading dos modelos -->
              <div v-if="apiConfigStore.loading && apiConfigStore.hasApiKey" class="text-center py-4">
                <v-progress-circular
                  indeterminate
                  color="primary"
                  size="32"
                ></v-progress-circular>
                <p class="mt-2 text-caption">Carregando modelos...</p>
              </div>

              <!-- Select de modelos -->
              <v-select
                v-if="canSelectModel"
                v-model="selectedModel"
                :items="apiConfigStore.models"
                label="Selecione o modelo"
                prepend-inner-icon="mdi-format-list-bulleted"
                variant="outlined"
                :disabled="apiConfigStore.saving || !apiConfigStore.hasApiKey"
              ></v-select>

              <!-- Alerta quando o modelo selecionado não é de chat -->
              <v-alert
                v-if="selectedModel && !isChatModel"
                type="warning"
                variant="tonal"
                class="mt-4"
              >
                <v-icon start>mdi-alert</v-icon>
                <strong>Atenção:</strong> O modelo <strong>{{ selectedModel }}</strong> não é um modelo de chat.
                <br>
                Ele usa o endpoint antigo <code>/v1/completions</code> em vez de <code>/v1/chat/completions</code>.
                <br>
                O bot funcionará, mas pode ter comportamento diferente dos modelos GPT de chat. Ele trata tudo como um texto contínuo e tenta continuar a história.
              </v-alert>

              <!-- Botão para salvar o modelo -->
              <v-btn
                v-if="canSelectModel && selectedModel"
                color="primary"
                :loading="apiConfigStore.saving"
                :disabled="!selectedModel || apiConfigStore.saving || !apiConfigStore.hasApiKey"
                @click="handleSaveModel"
                class="mt-4"
              >
                <v-icon start>mdi-content-save</v-icon>
                Salvar Modelo
              </v-btn>

              <!-- Mensagem quando não há API key -->
              <v-alert
                v-else-if="!apiConfigStore.hasApiKey"
                type="info"
                variant="tonal"
              >
                <v-icon start>mdi-information</v-icon>
                Configure a API key primeiro para ver os modelos disponíveis.
              </v-alert>

              <!-- Mensagem quando há API key mas não carregou modelos -->
              <v-alert
                v-else-if="apiConfigStore.hasApiKey && apiConfigStore.models.length === 0 && !apiConfigStore.loading && apiConfigStore.error"
                type="warning"
                variant="tonal"
                class="mt-4"
                >
                <v-icon start>mdi-alert</v-icon>
                {{ apiConfigStore.error }}
                <div class="mt-2">
                    <v-btn
                    size="small"
                    variant="outlined"
                    color="warning"
                    @click="isEditingApiKey = true"
                    >
                    Redefinir API Key
                    </v-btn>
                </div>
                </v-alert>

              <!-- Modelo atual -->
              <v-alert
                v-if="apiConfigStore.currentModel"
                type="success"
                variant="tonal"
                class="mt-4"
              >
                <v-icon start>mdi-check-circle</v-icon>
                Modelo atual: <strong>{{ apiConfigStore.currentModel }}</strong>
              </v-alert>
            </v-card-text>
          </v-card>

          <!-- Informações adicionais -->
          <v-card variant="outlined" class="mt-6">
            <v-card-text>
              <h3 class="text-subtitle-1 mb-2">
                <v-icon start size="small">mdi-information</v-icon>
                Como funciona?
              </h3>
              <ul class="text-body-2">
                <li>Digite sua API key da OpenAI e clique em "Salvar API Key"</li>
                <li>A API key será validada automaticamente</li>
                <li>Após salvar, os modelos disponíveis serão carregados</li>
                <li>Selecione o modelo que o bot usará para responder</li>
                <li>Quando alguém enviar uma mensagem contendo "@bot", o bot responderá automaticamente</li>
              </ul>
            </v-card-text>
          </v-card>
        </v-card>
      </v-container>
    </v-main>
  </div>
</template>