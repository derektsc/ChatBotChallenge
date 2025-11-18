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

// Configuração do tema Vuetify com paletas modernas e elegantes
const vuetify = createVuetify({
  components,
  directives,
  icons: { defaultSet: 'mdi', aliases, sets: { mdi } },
  theme: {
    defaultTheme: 'dark',
    themes: {
      dark: {
        dark: true,
        colors: {
          primary: '#E38E1C', // Terracota dourado suave
          secondary: '#C77D32', // Terracota mais profundo
          accent: '#F2C681', // Areia quente

          // Feedback (neutros, não vibrantes para não cansar)
          error: '#F87171',
          info: '#60A5FA',
          success: '#34D399',
          warning: '#FBBF24',
          background: '#121212', // Dark
          surface: '#1E1E1E', // Cartões/macrosurfaces
          'surface-variant': '#2A2A2A', // Bordas e seções

          // Texto e contraste
          'on-surface': '#F5F5F5', // Texto primário suave
          'on-primary': '#1A1A1A', // Texto sobre terracota

          // Chat
          'chat-user': '#E0A458',
          'chat-agent': '#1E1E1E'
        },
      },
      light: {
        dark: false,
        colors: {
          primary: '#E38E1C',
          secondary: '#F59E0B',
          accent: '#FBBF24',

          error: '#EF4444',
          info: '#3B82F6',
          success: '#22C55E',
          warning: '#F59E0B',

          background: '#FFF7ED',
          surface: '#FFFFFF',
          'surface-variant': '#FEF3C7',

          'on-surface': '#3B2F19',
          'on-primary': '#FFFFFF',

          'chat-user': '#E38E1C',
          'chat-agent': '#FFFFFF'
        },
      }
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
