<script setup>
import { ref, onMounted, computed, onUnmounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useTheme } from 'vuetify'
import { useDisplay } from 'vuetify'
import { useAuthStore } from '../stores/auth'
import { useRoomsStore } from '../stores/rooms'
import { useThemeStore } from '../stores/theme'
import { useMessagesStore } from '../stores/messages'
import ChatView from '../components/ChatView.vue'
import { createConsumer } from '@rails/actioncable'

const router = useRouter()
const authStore = useAuthStore()
const roomsStore = useRoomsStore()
const themeStore = useThemeStore()
const messagesStore = useMessagesStore()
const { mobile } = useDisplay()

const { theme } = useTheme()

// Estado para o diálogo de criar nova sala
const showCreateDialog = ref(false)
const newRoomTitle = ref('')
const creatingRoom = ref(false)

// Tab ativa: 'open' (abertas) ou 'closed' (concluídas)
const activeTab = ref('open')

// Estado para controlar sidebar em mobile
const showSidebar = ref(true) // Sempre começa visível

// Variável para armazenar a conexão ActionCable única
let cable = null
let roomsCableSubscription = null
let roomCableSubscriptions = {} // { roomId: subscription }

// Carrega dados quando o componente é montado
onMounted(async () => {
  authStore.loadFromStorage()
  
  if (!authStore.isAuthenticated()) {
    router.push('/login')
    return
  }

  authStore.setupAxiosInterceptor()

  if (theme && typeof theme.change === 'function') {
    theme.change(themeStore.currentTheme)
  }

  try {
    await roomsStore.fetchRooms()
  } catch (error) {
    // console.error('Erro ao carregar salas:', error)
  }

  // Conecta ao ActionCable
  connectToActionCable()
  
  // Se inscreve em todas as salas existentes para receber mensagens
  roomsStore.rooms.forEach(room => {
    subscribeToRoom(room.id)
  })
})

// Observa mudanças no mobile para ajustar sidebar
watch(mobile, (newValue) => {
  if (newValue && roomsStore.currentRoom) {
    // Em mobile, fecha sidebar quando abre chat
    showSidebar.value = false
  } else if (!newValue) {
    // Em desktop, sempre mostra sidebar
    showSidebar.value = true
  }
})

// Observa mudanças nas salas para se inscrever automaticamente
watch(() => roomsStore.rooms, (newRooms) => {
  newRooms.forEach(room => {
    if (!roomCableSubscriptions[room.id]) {
      subscribeToRoom(room.id)
    }
  })
}, { deep: true })

// Limpa conexões quando o componente é desmontado
onUnmounted(() => {
  if (roomsCableSubscription) {
    roomsCableSubscription.unsubscribe()
  }
  // Desconecta de todas as salas
  Object.values(roomCableSubscriptions).forEach(sub => {
    if (sub) sub.unsubscribe()
  })
  if (cable) {
    cable.disconnect()
  }
})

// Função para criar uma única conexão ActionCable
const connectToActionCable = () => {
  try {
    const backendUrl = import.meta.env.VITE_API_URL || 'http://localhost:3000'
    const wsUrl = backendUrl.replace(/^http/, 'ws')
    
    // Obtém o token JWT do store
    const token = authStore.token
    
    if (!token) {
      //console.error('Token JWT não encontrado')
      return
    }
    
    // Cria uma única conexão ActionCable com o token
    // O token será enviado como query parameter para autenticação
    cable = createConsumer(`${wsUrl}/cable?token=${encodeURIComponent(token)}`)
    
    // Se inscreve no channel geral de salas
    roomsCableSubscription = cable.subscriptions.create(
      { channel: 'RoomsChannel' },
      {
        received(data) {
          // Removido console.log - dados recebidos do ActionCable
          
          if (data.type === 'room_created') {
            const existingRoom = roomsStore.rooms.find(r => r.id === data.room.id)
            if (!existingRoom) {
              roomsStore.rooms.unshift(data.room)
              // Se inscreve automaticamente na nova sala
              subscribeToRoom(data.room.id)
            }
          } else if (data.type === 'room_closed') {
            const room = roomsStore.rooms.find(r => r.id === data.room.id)
            if (room) {
              room.status = 'closed'
            }
          } else if (data.type === 'room_deleted') {
            roomsStore.rooms = roomsStore.rooms.filter(r => r.id !== data.room_id)
            if (roomsStore.currentRoom?.id === data.room_id) {
              roomsStore.clearCurrentRoom()
            }
            // Desconecta do ActionCable da sala
            if (roomCableSubscriptions[data.room_id]) {
              roomCableSubscriptions[data.room_id].unsubscribe()
              delete roomCableSubscriptions[data.room_id]
            }
          } else if (data.type === 'room_message_count_updated') {
            // Atualiza contador de mensagens da sala
            const room = roomsStore.rooms.find(r => r.id === data.room_id)
            if (room) {
              room.messages_count = data.messages_count
            }
          }
        },
        connected() {
          // console.log('Conectado ao ActionCable - RoomsChannel')
        },
        disconnected() {
          //console.log('Desconectado do ActionCable')
        },
        rejected() {
          // Removido console.error - conexão rejeitada
        }
      }
    )
  } catch (error) {
    // Removido console.error - erro ao conectar
  }
}

// Função para se inscrever em uma sala específica para receber mensagens
const subscribeToRoom = (roomId) => {
  // Verifica se já está inscrito
  if (roomCableSubscriptions[roomId] || !cable) {
    return
  }

  try {
    // Se inscreve no channel específico da sala usando a mesma conexão
    const subscription = cable.subscriptions.create(
      { channel: 'RoomsChannel', room_id: roomId },
      {
        received(data) {
          // console.log('📨 Nova mensagem recebida na sala', roomId, ':', data)
          
          if (data.type === 'new_message') {
            const message = data.message
            
            // Adiciona a mensagem ao store
            messagesStore.addMessage(roomId, message)
            
            // Se a sala está aberta (é a atual), marca como lida
            if (roomsStore.currentRoom?.id === roomId) {
              messagesStore.markAsRead(roomId)
            } else {
              // Se não está aberta, incrementa contador de não lidas
              messagesStore.incrementUnread(roomId)
            }
          }
        },
        connected() {
        //  console.log(`Conectado à sala ${roomId}`)
        },
        disconnected() {
        //  console.log(`Desconectado da sala ${roomId}`)
        }
      }
    )
    
    roomCableSubscriptions[roomId] = subscription
  } catch (error) {
    // console.error(`Erro ao conectar à sala ${roomId}:`, error)
  }
}

// Função para criar uma nova sala
const handleCreateRoom = async () => {
  if (!newRoomTitle.value.trim()) {
    return
  }

  creatingRoom.value = true

  try {
    await roomsStore.createRoom(newRoomTitle.value)
    newRoomTitle.value = ''
    showCreateDialog.value = false
    activeTab.value = 'open'
  } catch (error) {
    // console.error('Erro ao criar sala:', error)
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
      // console.error('Erro ao fechar sala:', error)
    }
  }
}

// Função para excluir sala permanentemente
const handleDeleteRoom = async (roomId, event) => {
  event.stopPropagation()
  
  if (confirm('Tem certeza que deseja EXCLUIR PERMANENTEMENTE esta sala? Esta ação não pode ser desfeita e todas as mensagens serão perdidas.')) {
    try {
      await roomsStore.deleteRoom(roomId)
      // Desconecta do ActionCable da sala
      if (roomCableSubscriptions[roomId]) {
        roomCableSubscriptions[roomId].unsubscribe()
        delete roomCableSubscriptions[roomId]
      }
    } catch (error) {
    //  console.error('Erro ao excluir sala:', error)
    }
  }
}

// Função para selecionar uma sala
const handleSelectRoom = async (room) => {
  roomsStore.setCurrentRoom(room)
  
  // Em mobile, fecha sidebar quando abre chat
  if (mobile.value) {
    showSidebar.value = false
  }
  
  // Se inscreve na sala para receber mensagens em tempo real (se ainda não estiver)
  subscribeToRoom(room.id)
  
  // Carrega as mensagens da sala selecionada
  try {
    await messagesStore.fetchMessages(room.id)
    // Marca como lida
    messagesStore.markAsRead(room.id)
  } catch (error) {
    // console.error('Erro ao carregar mensagens:', error)
  }
}

// Função para voltar à lista (mobile)
const handleBackToList = () => {
  roomsStore.clearCurrentRoom()
  showSidebar.value = true
}

// Função para abrir/fechar sidebar (mobile)
const toggleSidebar = () => {
  showSidebar.value = !showSidebar.value
}

// Função para configurar o bot
const handleConfigureBot = () => {
  router.push('/config-bot')
}

// Função para alternar tema
const toggleTheme = () => {
  themeStore.toggleTheme()
  if (theme && typeof theme.change === 'function') {
    theme.change(themeStore.currentTheme)
  }
}

// Formata a data
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

// Computed para verificar se há uma sala selecionada
const hasSelectedRoom = computed(() => {
  return !!roomsStore.currentRoom
})
</script>

<template>
  <div class="rooms-layout">
    <!-- Barra superior -->
    <v-app-bar color="primary" prominent>
      <!-- Botão menu (mobile) - para abrir sidebar -->
      <v-btn
        v-if="mobile && !hasSelectedRoom"
        icon
        variant="text"
        @click="toggleSidebar"
        class="mr-2"
      >
        <v-icon>mdi-menu</v-icon>
      </v-btn>

      <!-- Botão voltar (mobile) - quando chat está aberto -->
      <v-btn
        v-if="mobile && hasSelectedRoom"
        icon
        variant="text"
        @click="handleBackToList"
        class="mr-2"
      >
        <v-icon>mdi-arrow-left</v-icon>
      </v-btn>

      <v-app-bar-title>
        <v-icon start>mdi-chat-processing</v-icon>
        Chat de Atendimento
      </v-app-bar-title>

      <v-spacer></v-spacer>

      <!-- Botão para alternar tema -->
      <v-btn
          :color="themeStore.isDark ? 'warning' : 'primary'"
          variant="flat"
          @click="toggleTheme"
          class="mr-2 theme-toggle-btn"
          >
            <v-icon start>{{ themeStore.isDark ? 'mdi-weather-sunny' : 'mdi-weather-night' }}</v-icon>
            <span class="d-none d-sm-inline">{{ themeStore.isDark ? 'Claro' : 'Escuro' }}</span>
      </v-btn>

      <!-- Botão para configurar o bot -->
      <v-btn
        color="accent"
        variant="flat"
        prepend-icon="mdi-robot"
        @click="handleConfigureBot"
        class="mr-2 configure-bot-btn"
        :class="{ 'd-none': mobile }"
      >
        <span class="d-none d-md-inline">Configurar @Bot</span>
        <span class="d-md-none">@Bot</span>
      </v-btn>

      <!-- Informações do usuário logado -->
      <v-chip class="mr-2" style="background-color: #e7e7e7; font-weight: bold; color: #000;">
        <v-icon start size="small">mdi-account</v-icon>
        {{ authStore.user?.name }}
      </v-chip>

      <!-- Botão de logout -->
      <v-btn
        icon="mdi-logout"
        variant="text"
        style="background-color: #f15252 !important;"
        @click="authStore.logout(); router.push('/login')"
      ></v-btn>
    </v-app-bar>

    <!-- Layout principal: duas colunas -->
    <v-main class="main-content">
      <div class="rooms-container">
        <!-- Sidebar esquerda: Lista de salas -->
        <v-navigation-drawer
          v-model="showSidebar"
          :temporary="mobile"
          :permanent="!mobile"
          width="380"
          class="rooms-sidebar"
        >
          <!-- Cabeçalho da sidebar com tabs melhoradas -->
          <v-toolbar color="surface" density="compact" class="sidebar-header">
            <v-tabs 
              v-model="activeTab" 
              color="primary" 
              class="rooms-tabs"
              slider-color="primary"
            >
              <v-tab value="open" class="tab-item">
                <v-icon start size="small">mdi-chat</v-icon>
                <span class="tab-label">Ativas</span>
                <v-chip 
                  v-if="roomsStore.openRooms.length > 0"
                  size="x-small"
                  color="primary"
                  class="ml-2"
                >
                  {{ roomsStore.openRooms.length }}
                </v-chip>
              </v-tab>
              <v-tab value="closed" class="tab-item">
                <v-icon start size="small">mdi-archive</v-icon>
                <span class="tab-label">Concluídas</span>
                <v-chip 
                  v-if="roomsStore.closedRooms.length > 0"
                  size="x-small"
                  color="secondary"
                  class="ml-2"
                >
                  {{ roomsStore.closedRooms.length }}
                </v-chip>
              </v-tab>
            </v-tabs>
            <v-spacer></v-spacer>
            <v-btn
              icon="mdi-plus"
              size="small"
              variant="text"
              @click="showCreateDialog = true"
              class="mr-2"
            ></v-btn>
          </v-toolbar>

          <!-- Lista de salas -->
          <v-list class="rooms-list" density="comfortable">
            <template v-if="activeRooms.length > 0">
              <v-list-item
                v-for="room in activeRooms"
                :key="room.id"
                :value="room.id"
                class="room-item"
                :class="{
                  'room-closed': room.status === 'closed',
                  'room-selected': roomsStore.currentRoom?.id === room.id
                }"
                @click="handleSelectRoom(room)"
              >
                <template v-slot:prepend>
                  <v-avatar 
                    color="primary" 
                    size="48"
                    class="mr-3"
                  >
                    <v-icon>mdi-chat</v-icon>
                  </v-avatar>
                </template>

                <v-list-item-title class="room-title">
                  {{ room.title }}
                </v-list-item-title>
                <v-list-item-subtitle class="room-subtitle">
                  <span v-if="room.messages_count > 0">
                    {{ room.messages_count }} mensagem{{ room.messages_count !== 1 ? 's' : '' }}
                  </span>
                  <span v-else>Nenhuma mensagem ainda</span>
                </v-list-item-subtitle>

                <template v-slot:append>
                  <div class="room-meta">
                    <div class="room-time">{{ formatTime(room.created_at) }}</div>
                    <!-- Badge de mensagens não lidas -->
                    <v-badge
                      v-if="messagesStore.getUnreadCount(room.id) > 0"
                      :content="messagesStore.getUnreadCount(room.id)"
                      color="error"
                      overlap
                      class="mr-2"
                    >
                      <v-icon size="small" color="primary">mdi-circle</v-icon>
                    </v-badge>
                    <v-menu location="bottom end">
                      <template v-slot:activator="{ props: menuProps }">
                        <v-btn
                          icon
                          variant="text"
                          size="x-small"
                          v-bind="menuProps"
                          @click.stop
                          class="menu-button"
                        >
                          <v-icon size="small">mdi-dots-vertical</v-icon>
                        </v-btn>
                      </template>
                      <v-list density="compact">
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
            </template>

            <!-- Mensagem quando não há salas -->
            <div v-else class="text-center py-12 pa-4 empty-state">
              <v-icon size="64" color="grey-lighten-1" class="mb-4">
                mdi-chat-outline
              </v-icon>
              <p class="text-body-2 text-medium-emphasis">
                <span v-if="activeTab === 'open'">
                  Nenhuma sala ativa. Crie uma nova!
                </span>
                <span v-else>
                  Nenhuma sala concluída ainda.
                </span>
              </p>
            </div>
          </v-list>
        </v-navigation-drawer>

        <!-- Área principal: Chat ou tela vazia -->
        <div class="chat-area">
          <ChatView
            v-if="hasSelectedRoom"
            :room="roomsStore.currentRoom"
          />
          <div v-else class="empty-chat">
            <v-icon size="120" color="grey-lighten-1" class="mb-4">
              mdi-chat-outline
            </v-icon>
            <h2 class="text-h5 mb-2">Selecione uma sala</h2>
            <p class="text-body-1 text-medium-emphasis">
              <span v-if="mobile">
                Toque no menu acima para ver as salas disponíveis
              </span>
              <span v-else>
                Escolha uma sala na lista ao lado para começar a conversar
              </span>
            </p>
            <!-- Botão para abrir sidebar em mobile -->
            <v-btn
              v-if="mobile"
              color="primary"
              prepend-icon="mdi-menu"
              @click="toggleSidebar"
              class="mt-4"
            >
              Ver Salas
            </v-btn>
          </div>
        </div>
      </div>
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
.rooms-layout {
  height: 100vh;
  display: flex;
  flex-direction: column;
}

.rooms-container {
  display: flex;
  height: 100%;
  max-height: 100vh; 
  overflow: hidden; 
  position: relative;
}

.rooms-sidebar {
  border-right: 1px solid rgba(255, 255, 255, 0.12);
  height: 100%;
}

.sidebar-header {
  border-bottom: 1px solid rgba(255, 255, 255, 0.12);
}

.rooms-tabs {
  flex: 1;
  min-width: 80%;
}

.rooms-tabs :deep(.v-tab) {
  min-width: 120px;
  padding: 12px 16px;
  font-size: 14px;
  font-weight: 500;
  text-transform: none;
  letter-spacing: normal;
}

.rooms-tabs :deep(.v-tab__content) {
  display: flex;
  align-items: center;
  gap: 6px;
}

.tab-item {
  display: flex;
  align-items: center;
  gap: 6px;
}

.main-content {
  height: 100%;
  max-height: 100vh;
  overflow: hidden;
}

.tab-label {
  white-space: nowrap;
}

.rooms-list {
  padding: 0;
  overflow-y: auto;
  height: calc(100% - 64px);
}

.room-item {
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  cursor: pointer;
  transition: background-color 0.2s;
  padding: 12px 16px !important;
}

.room-item:hover {
  background-color: rgba(255, 255, 255, 0.05);
}

.room-item.room-selected {
  background-color: rgba(var(--v-theme-primary), 0.15);
  border-left: 3px solid rgb(var(--v-theme-primary));
}

.room-item.room-closed {
  opacity: 0.6;
}

.room-title {
  font-weight: 500;
  font-size: 15px;
  line-height: 1.4;
}

.room-subtitle {
  font-size: 13px;
  margin-top: 4px;
  line-height: 1.3;
}

.room-meta {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
  min-width: 40px;
}

.theme-toggle-btn {
  font-weight: 500;
  text-transform: none;
  letter-spacing: normal;
  min-width: auto;
  padding: 8px 16px;
}

.configure-bot-btn {
  font-weight: 600;
  text-transform: none;
  letter-spacing: normal;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
  transition: all 0.3s ease;
}

.configure-bot-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
}

/* Em mobile, mostra apenas o ícone do bot */
@media (max-width: 600px) {
  .theme-toggle-btn {
    padding: 8px;
  }
  
  .theme-toggle-btn span {
    display: none !important;
  }
}

.room-time {
  font-size: 11px;
  opacity: 0.7;
  white-space: nowrap;
}

.menu-button {
  opacity: 0.6;
}

.menu-button:hover {
  opacity: 1;
}

.empty-state {
  padding: 32px 16px;
}

.chat-area {
  flex: 1;
  display: flex;
  flex-direction: column;
  height: 100%;
  max-height: 100%;
  min-height: 0; /* Importante para flexbox */
  overflow: hidden; /* Previne scroll no container pai */
  width: 100%;
  position: relative; /* Para posicionamento absoluto em mobile */
}

.empty-chat {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  text-align: center;
  padding: 32px;
}

/* Responsividade Mobile */
@media (max-width: 960px) {
  .rooms-container {
    position: relative;
  }

  .chat-area {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 1;
  }

  .rooms-sidebar {
    z-index: 2;
  }
}

/* Scrollbar personalizada */
.rooms-list::-webkit-scrollbar {
  width: 6px;
}

.rooms-list::-webkit-scrollbar-track {
  background: transparent;
}

.rooms-list::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 3px;
}

.rooms-list::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3);
}

/* Esconde os botões de navegação do v-slide-group */
.rooms-tabs :deep(.v-slide-group__next),
.rooms-tabs :deep(.v-slide-group__prev) {
  display: none !important;
}
</style>