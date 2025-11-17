<script setup>
import { ref, onMounted, computed, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useTheme } from 'vuetify'
import { useAuthStore } from '../stores/auth'
import { useRoomsStore } from '../stores/rooms'
import { useThemeStore } from '../stores/theme'
import { createConsumer } from '@rails/actioncable'

const router = useRouter()
const authStore = useAuthStore()
const roomsStore = useRoomsStore()
const themeStore = useThemeStore()

// Obtém o tema do Vuetify corretamente
// useTheme() retorna { theme, global, current }
// O objeto theme tem o método change()
const { theme } = useTheme()

// Estado para o diálogo de criar nova sala
const showCreateDialog = ref(false)
const newRoomTitle = ref('')
const creatingRoom = ref(false)

// Tab ativa: 'open' (abertas) ou 'closed' (concluídas)
const activeTab = ref('open')

// Variável para armazenar a conexão ActionCable
let cableSubscription = null

// Carrega dados quando o componente é montado
onMounted(async () => {
  authStore.loadFromStorage()
  
  if (!authStore.isAuthenticated()) {
    router.push('/login')
    return
  }

  authStore.setupAxiosInterceptor()

  // Aplica o tema salvo usando theme.change()
  if (theme && typeof theme.change === 'function') {
    theme.change(themeStore.currentTheme)
  }

  // Busca as salas iniciais
  try {
    await roomsStore.fetchRooms()
  } catch (error) {
    console.error('Erro ao carregar salas:', error)
  }

  // Conecta ao ActionCable para receber atualizações em tempo real
  connectToActionCable()
})

// Limpa a conexão quando o componente é desmontado
onUnmounted(() => {
  if (cableSubscription) {
    cableSubscription.unsubscribe()
  }
})

// Função para conectar ao ActionCable
const connectToActionCable = () => {
  try {
    // Detecta a URL do backend dinamicamente
    const backendUrl = import.meta.env.VITE_API_URL || 'http://localhost:3000'
    const wsUrl = backendUrl.replace(/^http/, 'ws')
    
    // Cria a conexão WebSocket com o backend
    const cable = createConsumer(`${wsUrl}/cable`)
    
    // Se inscreve no channel "RoomsChannel" para receber atualizações
    cableSubscription = cable.subscriptions.create(
      { channel: 'ApplicationCable::RoomsChannel' },
      {
        // Método chamado quando recebe uma mensagem do servidor
        received(data) {
          console.log('Dados recebidos do ActionCable:', data)
          
          if (data.type === 'room_created') {
            // Verifica se a sala já não existe na lista (evita duplicatas)
            const existingRoom = roomsStore.rooms.find(r => r.id === data.room.id)
            if (!existingRoom) {
              // Adiciona a nova sala no início da lista
              roomsStore.rooms.unshift(data.room)
            }
          } else if (data.type === 'room_closed') {
            // Atualiza o status da sala
            const room = roomsStore.rooms.find(r => r.id === data.room.id)
            if (room) {
              room.status = 'closed'
            }
          } else if (data.type === 'room_deleted') {
            // Remove a sala da lista
            roomsStore.rooms = roomsStore.rooms.filter(r => r.id !== data.room_id)
          }
        },

        // Método chamado quando a conexão é estabelecida
        connected() {
          console.log('Conectado ao ActionCable - RoomsChannel')
        },

        // Método chamado quando a conexão é perdida
        disconnected() {
          console.log('Desconectado do ActionCable')
        },

        // Método chamado quando há erro na conexão
        rejected() {
          console.error('Conexão ActionCable rejeitada')
        }
      }
    )
  } catch (error) {
    console.error('Erro ao conectar ao ActionCable:', error)
  }
}

// Função para criar uma nova sala
const handleCreateRoom = async () => {
  if (!newRoomTitle.value.trim()) {
    return
  }

  creatingRoom.value = true

  try {
    // Cria a sala no backend
    // O ActionCable vai notificar todos os usuários (incluindo este) sobre a nova sala
    await roomsStore.createRoom(newRoomTitle.value)
    newRoomTitle.value = ''
    showCreateDialog.value = false
    activeTab.value = 'open'
  } catch (error) {
    console.error('Erro ao criar sala:', error)
  } finally {
    creatingRoom.value = false
  }
}

// Função para marcar sala como concluída
const handleCloseRoom = async (roomId, event) => {
  event.stopPropagation()
  
  if (confirm('Tem certeza que deseja marcar esta sala como atendimento concluído?')) {
    try {
      await roomsStore.closeRoom(roomId)
    } catch (error) {
      console.error('Erro ao fechar sala:', error)
    }
  }
}

// Função para excluir sala permanentemente
const handleDeleteRoom = async (roomId, event) => {
  event.stopPropagation()
  
  if (confirm('Tem certeza que deseja EXCLUIR PERMANENTEMENTE esta sala? Esta ação não pode ser desfeita e todas as mensagens serão perdidas.')) {
    try {
      await roomsStore.deleteRoom(roomId)
    } catch (error) {
      console.error('Erro ao excluir sala:', error)
    }
  }
}

// Função para entrar em uma sala
const handleEnterRoom = (room) => {
  alert(`Entrando na sala: ${room.title}\n\n(Esta funcionalidade será implementada no próximo passo)`)
}

// Função para configurar o bot
const handleConfigureBot = () => {
  alert('Tela de configuração do bot será implementada em breve')
}

// Função para alternar tema
const toggleTheme = () => {
  themeStore.toggleTheme()
  // Usa theme.change() que é a API recomendada
  if (theme && typeof theme.change === 'function') {
    theme.change(themeStore.currentTheme)
  }
}

// Formata a data de forma mais amigável (estilo WhatsApp)
const formatDate = (dateString) => {
  const date = new Date(dateString)
  const now = new Date()
  const diffTime = Math.abs(now - date)
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))

  if (diffDays === 1) {
    return 'Hoje'
  } else if (diffDays === 2) {
    return 'Ontem'
  } else if (diffDays <= 7) {
    return date.toLocaleDateString('pt-BR', { weekday: 'short' })
  } else {
    return date.toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: '2-digit'
    })
  }
}

// Formata a hora
const formatTime = (dateString) => {
  const date = new Date(dateString)
  return date.toLocaleTimeString('pt-BR', {
    hour: '2-digit',
    minute: '2-digit'
  })
}

// Computed para obter as salas da aba ativa
const activeRooms = computed(() => {
  return activeTab.value === 'open' 
    ? roomsStore.openRooms 
    : roomsStore.closedRooms
})
</script>

<template>
  <div>
    <!-- Barra superior (App Bar) estilo WhatsApp -->
    <v-app-bar color="primary" prominent>
      <v-app-bar-title>
        <v-icon start>mdi-chat-processing</v-icon>
        Chat de Atendimento
      </v-app-bar-title>

      <v-spacer></v-spacer>

      <!-- Botão para alternar tema -->
      <v-btn
        icon
        variant="text"
        @click="toggleTheme"
        class="mr-2"
      >
        <v-icon>{{ themeStore.isDark ? 'mdi-weather-sunny' : 'mdi-weather-night' }}</v-icon>
      </v-btn>

      <!-- Botão para configurar o bot -->
      <v-btn
        color="secondary"
        variant="outlined"
        prepend-icon="mdi-robot"
        @click="handleConfigureBot"
        class="mr-2"
      >
        Configurar @Bot
      </v-btn>

      <!-- Informações do usuário logado -->
      <v-chip color="surface" class="mr-2">
        <v-icon start size="small">mdi-account</v-icon>
        {{ authStore.user?.name }}
      </v-chip>

      <!-- Botão de logout -->
      <v-btn
        icon="mdi-logout"
        variant="text"
        @click="authStore.logout(); router.push('/login')"
      ></v-btn>
    </v-app-bar>

    <!-- Conteúdo principal -->
    <v-main>
      <v-container fluid class="pa-0">
        <!-- Tabs para alternar entre salas abertas e concluídas -->
        <v-tabs v-model="activeTab" color="primary" class="rooms-tabs">
          <v-tab value="open">
            <v-icon start>mdi-chat</v-icon>
            Ativas ({{ roomsStore.openRooms.length }})
          </v-tab>
          <v-tab value="closed">
            <v-icon start>mdi-archive</v-icon>
            Concluídas ({{ roomsStore.closedRooms.length }})
          </v-tab>
        </v-tabs>

        <!-- Botão flutuante para criar nova sala (usando v-btn ao invés de v-fab) -->
        <v-btn
          class="fab-button"
          color="primary"
          icon="mdi-plus"
          size="large"
          @click="showCreateDialog = true"
        ></v-btn>

        <!-- Mensagem de erro -->
        <v-alert
          v-if="roomsStore.error"
          type="error"
          variant="tonal"
          closable
          class="ma-4"
          @click:close="roomsStore.error = null"
        >
          {{ roomsStore.error }}
        </v-alert>

        <!-- Loading -->
        <div v-if="roomsStore.loading && roomsStore.rooms.length === 0" class="text-center py-12">
          <v-progress-circular
            indeterminate
            color="primary"
            size="64"
          ></v-progress-circular>
          <p class="mt-4 text-body-1">Carregando salas...</p>
        </div>

        <!-- Lista de salas estilo WhatsApp -->
        <v-list v-else-if="activeRooms.length > 0" class="rooms-list">
          <v-list-item
            v-for="room in activeRooms"
            :key="room.id"
            class="room-item"
            :class="{ 'room-closed': room.status === 'closed' }"
            @click="handleEnterRoom(room)"
          >
            <!-- Avatar da sala -->
            <template v-slot:prepend>
              <v-avatar color="primary" size="56">
                <v-icon size="32">mdi-chat</v-icon>
              </v-avatar>
            </template>

            <!-- Conteúdo principal -->
            <v-list-item-title class="room-title">
              {{ room.title }}
            </v-list-item-title>
            <v-list-item-subtitle class="room-subtitle">
              <span v-if="room.messages_count > 0">
                {{ room.messages_count }} mensagem{{ room.messages_count !== 1 ? 's' : '' }}
              </span>
              <span v-else>Nenhuma mensagem ainda</span>
            </v-list-item-subtitle>

            <!-- Informações à direita -->
            <template v-slot:append>
              <div class="room-meta">
                <div class="room-time">{{ formatTime(room.created_at) }}</div>
                <div class="room-date">{{ formatDate(room.created_at) }}</div>
                
                <!-- Menu de ações -->
                <v-menu>
                  <template v-slot:activator="{ props }">
                    <v-btn
                      icon
                      variant="text"
                      size="small"
                      v-bind="props"
                      @click.stop
                    >
                      <v-icon>mdi-dots-vertical</v-icon>
                    </v-btn>
                  </template>
                  <v-list>
                    <v-list-item
                      v-if="room.status === 'open'"
                      prepend-icon="mdi-check-circle"
                      title="Marcar como concluída"
                      @click="handleCloseRoom(room.id, $event)"
                    ></v-list-item>
                    <v-list-item
                      prepend-icon="mdi-delete"
                      title="Excluir permanentemente"
                      @click="handleDeleteRoom(room.id, $event)"
                    ></v-list-item>
                  </v-list>
                </v-menu>
              </div>
            </template>
          </v-list-item>
        </v-list>

        <!-- Mensagem quando não há salas -->
        <v-card v-else class="text-center py-12 ma-4">
          <v-icon size="64" color="grey-lighten-1" class="mb-4">
            mdi-chat-outline
          </v-icon>
          <h3 class="text-h6 mb-2">Nenhuma sala {{ activeTab === 'open' ? 'ativa' : 'concluída' }}</h3>
          <p class="text-body-2 text-medium-emphasis mb-4">
            <span v-if="activeTab === 'open'">
              Crie uma nova sala para começar a conversar
            </span>
            <span v-else>
              Nenhuma sala foi concluída ainda
            </span>
          </p>
          <v-btn
            v-if="activeTab === 'open'"
            color="primary"
            prepend-icon="mdi-plus"
            @click="showCreateDialog = true"
          >
            Criar Primeira Sala
          </v-btn>
        </v-card>
      </v-container>
    </v-main>

    <!-- Diálogo para criar nova sala -->
    <v-dialog v-model="showCreateDialog" max-width="500">
      <v-card>
        <v-card-title>
          <span class="text-h5">Nova Sala de Atendimento</span>
        </v-card-title>

        <v-card-text>
          <v-text-field
            v-model="newRoomTitle"
            label="Título da sala"
            placeholder="Ex: Atendimento Cliente X"
            prepend-inner-icon="mdi-format-title"
            variant="outlined"
            autofocus
            :rules="[
              v => !!v || 'Título é obrigatório',
              v => (v && v.trim().length >= 3) || 'Título deve ter pelo menos 3 caracteres'
            ]"
            @keyup.enter="handleCreateRoom"
          ></v-text-field>
        </v-card-text>

        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn
            variant="text"
            @click="showCreateDialog = false; newRoomTitle = ''"
          >
            Cancelar
          </v-btn>
          <v-btn
            color="primary"
            :loading="creatingRoom"
            :disabled="!newRoomTitle.trim()"
            @click="handleCreateRoom"
          >
            Criar
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<style scoped>
.rooms-tabs {
  border-bottom: 1px solid rgba(255, 255, 255, 0.12);
}

.rooms-list {
  padding: 0;
  background: transparent;
}

.room-item {
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  cursor: pointer;
  transition: background-color 0.2s;
}

.room-item:hover {
  background-color: rgba(255, 255, 255, 0.05);
}

.room-item.room-closed {
  opacity: 0.6;
  background-color: rgba(255, 255, 255, 0.02);
}

.room-title {
  font-weight: 500;
  font-size: 16px;
}

.room-subtitle {
  font-size: 14px;
  margin-top: 4px;
}

.room-meta {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
}

.room-time {
  font-size: 12px;
  font-weight: 500;
}

.room-date {
  font-size: 11px;
  opacity: 0.7;
}

.fab-button {
  position: fixed;
  bottom: 24px;
  right: 24px;
  z-index: 1000;
}

/* Responsividade */
@media (max-width: 600px) {
  .room-meta {
    min-width: 80px;
  }
}
</style>