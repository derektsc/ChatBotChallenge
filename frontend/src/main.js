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
  icons: {
    defaultSet: 'mdi',
    aliases,
    sets: {
      mdi,
    },
  },
  theme: {
    defaultTheme: 'dark',
    themes: {
      dark: {
        dark: true,
        colors: {
          // Paleta principal - tons de azul/roxo modernos
          primary: '#667eea',        // Azul-roxo vibrante
          secondary: '#764ba2',       // Roxo profundo
          accent: '#f093fb',          // Rosa suave
          
          // Cores de feedback
          error: '#ef4444',           // Vermelho
          info: '#3b82f6',            // Azul
          success: '#10b981',         // Verde
          warning: '#f59e0b',         // Laranja
          
          // Cores de fundo - gradiente escuro elegante
          background: '#0a0e27',      // Azul muito escuro (quase preto)
          surface: '#1a1f3a',         // Azul escuro
          
          // Cores adicionais para melhor contraste
          'surface-variant': '#252b4a',
          'on-surface': '#e2e8f0',
          'on-primary': '#ffffff',
        },
      },
      light: {
        dark: false,
        colors: {
          // Paleta principal - tons suaves e elegantes
          primary: '#667eea',        // Azul-roxo (mesmo do dark para consistência)
          secondary: '#764ba2',       // Roxo profundo
          accent: '#f093fb',          // Rosa suave
          
          // Cores de feedback
          error: '#ef4444',
          info: '#3b82f6',
          success: '#10b981',
          warning: '#f59e0b',
          
          // Cores de fundo - branco suave e elegante
          background: '#f8fafc',      // Cinza muito claro (quase branco)
          surface: '#ffffff',         // Branco puro
          
          // Cores adicionais para melhor contraste
          'surface-variant': '#f1f5f9',
          'on-surface': '#1e293b',
          'on-primary': '#ffffff',
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
