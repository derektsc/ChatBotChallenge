import { defineStore } from 'pinia'

export const useThemeStore = defineStore('theme', {
  state: () => ({
    // Tema atual: 'light' ou 'dark'
    // Por padrão, usa o tema do sistema ou 'dark'
    currentTheme: localStorage.getItem('theme') || 'dark'
  }),

  actions: {
    // Alterna entre light e dark mode
    toggleTheme() {
      this.currentTheme = this.currentTheme === 'dark' ? 'light' : 'dark'
      // Salva a preferência no localStorage
      localStorage.setItem('theme', this.currentTheme)
    },

    // Define o tema explicitamente
    setTheme(theme) {
      if (theme === 'light' || theme === 'dark') {
        this.currentTheme = theme
        localStorage.setItem('theme', this.currentTheme)
      }
    }
  },

  getters: {
    // Retorna true se o tema atual for dark
    isDark: (state) => state.currentTheme === 'dark'
  }
})