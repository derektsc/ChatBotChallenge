<script setup>
import { ref, onMounted, watch, nextTick, computed } from 'vue'
import { useMessagesStore } from '../stores/messages'
import { useAuthStore } from '../stores/auth'
import { useRoomsStore } from '../stores/rooms'

const props = defineProps({
  room: {
    type: Object,
    required: true
  }
})

const messagesStore = useMessagesStore()
const authStore = useAuthStore()
const roomsStore = useRoomsStore()

// Estado do input de mensagem
const messageContent = ref('')
const messagesContainer = ref(null)

// Carrega mensagens quando o componente é montado ou quando a sala muda
onMounted(async () => {
  if (props.room) {
    await loadMessages()
  }
})

// Observa mudanças na sala
watch(() => props.room?.id, async (newRoomId) => {
  if (newRoomId) {
    await loadMessages()
  }
})

// Carrega as mensagens da sala
const loadMessages = async () => {
  try {
    await messagesStore.fetchMessages(props.room.id)
    // Scroll para o final após carregar
    await nextTick()
    scrollToBottom()
  } catch (error) {
    console.error('Erro ao carregar mensagens:', error)
  }
}

// Envia uma mensagem
const sendMessage = async () => {
  if (!messageContent.value.trim()) {
    return
  }

  const content = messageContent.value.trim()
  messageContent.value = ''

  try {
    await messagesStore.sendMessage(props.room.id, content)
    // Scroll para o final após enviar
    await nextTick()
    scrollToBottom()
  } catch (error) {
    console.error('Erro ao enviar mensagem:', error)
    // Restaura o conteúdo em caso de erro
    messageContent.value = content
  }
}

// Scroll para o final da lista de mensagens
const scrollToBottom = () => {
  if (messagesContainer.value) {
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
  }
}

// Formata a data/hora da mensagem
const formatMessageTime = (dateString) => {
  const date = new Date(dateString)
  return date.toLocaleTimeString('pt-BR', {
    hour: '2-digit',
    minute: '2-digit'
  })
}

// Verifica se a mensagem é do usuário atual
const isMyMessage = (message) => {
  return message.user.id === authStore.user?.id
}

// Obtém as mensagens da sala atual
const messages = computed(() => {
  if (!props.room?.id) {
    return []
  }
  
  const roomMessages = messagesStore.getMessagesByRoom(props.room.id)
  return roomMessages || []
})

// Observa mudanças nas mensagens para fazer scroll automático
watch(
  () => messages.value,
  () => {
    nextTick(() => {
      scrollToBottom()
    })
  },
  { deep: true, immediate: true }
)

// Observa mudanças na sala para recarregar mensagens
watch(
  () => props.room?.id,
  async (newRoomId, oldRoomId) => {
    if (newRoomId && newRoomId !== oldRoomId) {
      await loadMessages()
    }
  },
  { immediate: true }
)
</script>

<template>
  <div class="chat-view">
    <!-- Cabeçalho do chat -->
    <v-toolbar color="surface" density="compact" class="chat-header">
      <v-toolbar-title>
        <div class="d-flex align-center">
          <v-avatar color="primary" size="40" class="mr-3">
            <v-icon>mdi-chat</v-icon>
          </v-avatar>
          <div>
            <div class="text-subtitle-1 font-weight-medium">{{ room?.title }}</div>
            <div class="text-caption text-medium-emphasis">
              {{ room?.status === 'open' ? 'Ativa' : 'Concluída' }}
            </div>
          </div>
        </div>
      </v-toolbar-title>
    </v-toolbar>

    <!-- Área de mensagens -->
    <div ref="messagesContainer" class="messages-container">
     
      <!-- Loading -->
      <div v-if="messagesStore.loading" class="text-center py-8">
        <v-progress-circular
          indeterminate
          color="primary"
          size="32"
        ></v-progress-circular>
        <p class="mt-2 text-caption">Carregando mensagens...</p>
      </div>

      <!-- Lista de mensagens -->
      <template v-else-if="messages && messages.length > 0">
        <div class="messages-list">
          <div
            v-for="message in messages"
            :key="message.id"
            class="message-item"
            :class="{ 'message-mine': isMyMessage(message) }"
          >
            <div class="message-bubble">
              <div v-if="!isMyMessage(message)" class="message-author">
                {{ message.user?.name || 'Usuário desconhecido' }}
              </div>
              <div class="message-content">{{ message.content }}</div>
              <div class="message-time">{{ formatMessageTime(message.created_at) }}</div>
            </div>
          </div>
        </div>
      </template>

      <!-- Mensagem quando não há mensagens -->
      <div v-else class="text-center py-12">
        <v-icon size="64" color="grey-lighten-1" class="mb-4">
          mdi-message-outline
        </v-icon>
        <p class="text-body-1 text-medium-emphasis">
          Nenhuma mensagem ainda. Seja o primeiro a escrever!
        </p>
      </div>
    </div>

    <!-- Input de mensagem -->
    <v-card class="message-input-container" elevation="0">
      <div class="d-flex align-center pa-2">
        <v-text-field
          v-model="messageContent"
          placeholder="Digite sua mensagem..."
          variant="solo-filled"
          density="compact"
          hide-details
          class="message-input"
          @keyup.enter="sendMessage"
        ></v-text-field>
        <v-btn
          color="primary"
          icon="mdi-send"
          :disabled="!messageContent.trim() || messagesStore.isSending(room?.id)"
          :loading="messagesStore.isSending(room?.id)"
          @click="sendMessage"
          class="ml-2"
        ></v-btn>
      </div>
    </v-card>
  </div>
</template>

<style scoped>
.chat-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
  max-height: 100%;
  background: rgb(var(--v-theme-background));
  overflow: hidden;
}

.chat-header {
  border-bottom: 1px solid rgba(255, 255, 255, 0.12);
  flex-shrink: 0;
  min-height: 48px; 
}

.messages-container {
  flex: 1 1 auto; 
  min-height: 0; 
  max-height: 100%; 
  overflow-y: auto; 
  overflow-x: hidden;
  padding: 16px;
  background: rgb(var(--v-theme-background));
  position: relative;
}

.messages-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  min-height: min-content;
}

.message-item {
  display: flex;
  width: 100%;
  flex-shrink: 0; 
}

.message-item.message-mine {
  justify-content: flex-end;
}

.message-bubble {
  max-width: 70%;
  padding: 12px 16px;
  border-radius: 18px;
  position: relative;
  word-wrap: break-word; 
  overflow-wrap: break-word;
}

.message-item:not(.message-mine) .message-bubble {
  background: rgb(var(--v-theme-surface));
  border-bottom-left-radius: 4px;
}

.message-item.message-mine .message-bubble {
  background: rgb(var(--v-theme-primary));
  color: white;
  border-bottom-right-radius: 4px;
}

.message-author {
  font-size: 12px;
  font-weight: 600;
  margin-bottom: 4px;
  opacity: 0.8;
}

.message-content {
  word-wrap: break-word;
  overflow-wrap: break-word;
  line-height: 1.4;
  white-space: pre-wrap;
}

.message-time {
  font-size: 11px;
  margin-top: 4px;
  opacity: 0.7;
  text-align: right;
}

.message-input-container {
  border-top: 1px solid rgba(255, 255, 255, 0.12);
  flex-shrink: 0;
  min-height: 64px; 
}

.message-input {
  flex: 1;
}

/* Scrollbar personalizada */
.messages-container::-webkit-scrollbar {
  width: 6px;
}

.messages-container::-webkit-scrollbar-track {
  background: transparent;
}

.messages-container::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 3px;
}

.messages-container::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3);
}

@media (max-width: 960px) {
  .chat-view {
    height: 100vh;
    max-height: 100vh;
  }
}
</style>