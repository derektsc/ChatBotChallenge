import { createApp } from 'vue'
// Pinia é o gerenciador de estado
import { createPinia } from 'pinia'
// Vue Router para navegação entre páginas (Login, Rooms, etc.)
import router from './router'

// Vuetify - framework de UI para Vue.js
import 'vuetify/styles'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { aliases, mdi } from 'vuetify/iconsets/mdi'
import '@mdi/font/css/materialdesignicons.css'

// Componente raiz da aplicação
import App from './App.vue'
// Estilos globais
import './style.css'

// Configuração do tema Vuetify (dark mode moderno)
const vuetify = createVuetify({
  components,
  directives,
  icons: {
    defaultSet: 'mdi',
    aliases,
    sets: {
      mdi,
    },
  },
  theme: {
    // O tema será controlado dinamicamente pelo store
    defaultTheme: 'dark', // Tema inicial
    themes: {
      dark: {
        colors: {
          primary: '#6366f1',      // Indigo
          secondary: '#8b5cf6',    // Purple
          accent: '#ec4899',       // Pink
          error: '#ef4444',
          info: '#3b82f6',
          success: '#10b981',
          warning: '#f59e0b',
          background: '#0f172a',   // Slate 900
          surface: '#1e293b',      // Slate 800
        },
      },
      light: {
        colors: {
          primary: '#6366f1',      // Indigo
          secondary: '#8b5cf6',    // Purple
          accent: '#ec4899',       // Pink
          error: '#ef4444',
          info: '#3b82f6',
          success: '#10b981',
          warning: '#f59e0b',
          background: '#ffffff',   // Branco
          surface: '#f8f9fa',      // Cinza muito claro
        },
      },
    },
  },
})

const app = createApp(App)

// Instala Pinia na aplicação
const pinia = createPinia()
app.use(pinia)

// Instala o roteador
app.use(router)

// Instala o Vuetify na aplicação
app.use(vuetify)

// Sincroniza o tema do store com o Vuetify
// Usa theme.change() que é a API recomendada
import { useThemeStore } from './stores/theme'
const themeStore = useThemeStore()

// Aplica o tema salvo usando theme.change()
vuetify.theme.change(themeStore.currentTheme)

// Observa mudanças no tema
themeStore.$subscribe((mutation, state) => {
  vuetify.theme.change(state.currentTheme)
})

// Monta a aplicação no elemento <div id="app"></div> em index.html
app.mount('#app')
