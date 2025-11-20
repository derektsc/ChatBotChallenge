<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
// Importa o store de autenticação
import { useAuthStore } from '../stores/auth'
import { useThemeStore } from '../stores/theme'

// Pega o roteador para poder navegar para /rooms depois do login
const router = useRouter()
// Obtem o store de autenticação
const authStore = useAuthStore()
// Obtém o store de tema
const themeStore = useThemeStore()
// Campo reativo para armazenar o nome digitado no input
const name = ref('')
// Estado para exibir mensagens de erro simples
const errorMessage = ref('')
// Estado para exibir loading do botão de login
const loading = ref(false)

// Computed para verificar se está em dark mode
const isDark = computed(() => themeStore.isDark)

// Carrega dados do localStorage quando o componente monta
onMounted(() => {
  authStore.loadFromStorage()
  // Se já estiver autenticado, redireciona para /rooms
  if (authStore.isAuthenticated()) {
    router.push('/rooms')
  }
})

// Função chamada quando o usuário envia o formulário de login
const handleLogin = async () => {
    // Limpa mensagem de erro
    errorMessage.value = ''

    // Validação simples: Não permitir nome vazio
    if (!name.value.trim()) {
        errorMessage.value = 'Nome é obrigatório'
        return
    }

    try {
        // Chama a action login do store, que fala com o backend do Rails para fazer o login
        await authStore.login(name.value)

        // Caso de certo, redireciona para a tela das salas de chat
        router.push('/rooms')
    } catch (error) {
        // Em caso de erro na req:
        console.error('Erro ao fazer login:', error)
        errorMessage.value = 'Erro ao fazer login. Verifique se o nome está correto e tente novamente.'
    }
}
</script>

<template>
  <!-- v-container: container responsivo do Vuetify que se adapta ao tamanho da tela -->
  <v-container fluid class="login-container" :class="{ 'login-container-dark': isDark, 'login-container-light': !isDark }">
    <v-row justify="center" align="center" class="fill-height">
      <v-col cols="12" sm="8" md="6" lg="4" xl="3">
        <!-- v-card: card moderno do Vuetify com elevação e bordas arredondadas -->
        <v-card 
          class="login-card pa-8" 
          elevation="8"
          rounded="xl"
          :class="{ 'login-card-dark': isDark, 'login-card-light': !isDark }"
        >
          <!-- Cabeçalho do card -->
          <div class="text-center mb-8">
            <!-- Ícone de chat/atendimento -->
            <v-icon 
              size="64" 
              color="primary" 
              class="mb-4"
            >
              mdi-chat-processing
            </v-icon>
            
            <h1 class="text-h4 font-weight-bold mb-2 login-title">
              Chat de Atendimento
            </h1>
            
            <p class="text-body-1 login-subtitle">
              Digite seu nome para entrar no sistema
            </p>
          </div>

          <!-- Mensagem de erro (se houver) -->
          <v-alert
            v-if="errorMessage"
            type="error"
            variant="tonal"
            closable
            class="mb-4"
            @click:close="errorMessage = ''"
          >
            {{ errorMessage }}
          </v-alert>

          <!-- Formulário de login -->
          <v-form @submit.prevent="handleLogin">
            <!-- Campo de input para o nome -->
            <v-text-field
              v-model="name"
              label="Seu nome"
              placeholder="Ex: Ana, João, Maria..."
              prepend-inner-icon="mdi-account"
              variant="outlined"
              color="primary"
              :disabled="loading"
              autofocus
              class="mb-4"
              :rules="[
                v => !!v || 'Nome é obrigatório',
                v => (v && v.trim().length >= 2) || 'Nome deve ter pelo menos 2 caracteres'
              ]"
            />

            <!-- Botão de submit -->
            <v-btn
              type="submit"
              color="primary"
              size="large"
              block
              :loading="loading"
              :disabled="!name.trim() || loading"
              class="mt-2"
            >
              <v-icon start>mdi-login</v-icon>
              Entrar
            </v-btn>
          </v-form>

          <!-- Rodapé informativo -->
          <div class="text-center mt-6">
            <p class="text-caption login-footer">
              Sistema de chat em tempo real para atendimento ao cliente
            </p>
          </div>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<style scoped>

/* Dark Mode - Gradiente escuro */
.login-container-dark {
  min-height: 100vh;
  background: linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #334155 100%);
}

/* Light Mode - Gradiente claro com mais contraste */
.login-container-light {
  min-height: 100vh;
  background: linear-gradient(135deg, #E5E7EB 0%, #D1D5DB 50%, #9CA3AF 100%);
}

/* Dark Mode - Card com transparência escura */
.login-card-dark {
  background: rgba(30, 41, 59, 0.95) !important;
  backdrop-filter: blur(10px);
  border: 1px solid rgba(148, 163, 184, 0.1);
}

/* Light Mode - Card branco sólido com sombra */
.login-card-light {
  background: #FFFFFF !important;
  backdrop-filter: blur(10px);
  border: 1px solid rgba(0, 0, 0, 0.1);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12) !important;
}

/* Título - Dark Mode */
.login-card-dark .login-title {
  color: #F5F5F5 !important;
}

/* Título - Light Mode (texto escuro para contraste) */
.login-card-light .login-title {
  color: #1F2937 !important;
}

/* Subtítulo - Dark Mode */
.login-card-dark .login-subtitle {
  color: rgba(255, 255, 255, 0.7) !important;
}

/* Subtítulo - Light Mode (texto médio para contraste) */
.login-card-light .login-subtitle {
  color: #4B5563 !important;
}

/* Rodapé - Dark Mode */
.login-card-dark .login-footer {
  color: rgba(255, 255, 255, 0.6) !important;
}

/* Rodapé - Light Mode (texto médio para contraste) */
.login-card-light .login-footer {
  color: #6B7280 !important;
}

/* Animação suave ao carregar a página */
@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.login-card {
  animation: fadeIn 0.5s ease-out;
}

/* Responsividade: ajustes para telas muito pequenas */
@media (max-width: 600px) {
  .login-card {
    margin: 16px;
    padding: 24px !important;
  }
}
</style>