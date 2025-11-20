import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

// Import das views
import LoginView from '../views/LoginView.vue'
import RoomsView from '../views/RoomsView.vue'
import ConfigBotView from '../views/ConfigBotView.vue' 

const routes = [
    {
      path: '/login',
      name: 'Login',
      component: LoginView,
      // Se o usuário já estiver logado, redireciona para /rooms
      beforeEnter: (to, from, next) => {
        const authStore = useAuthStore()
        authStore.loadFromStorage()
        if (authStore.isAuthenticated()) {
          next('/rooms')
        } else {
          next()
        }
      }
    },
    {
      path: '/rooms',
      name: 'Rooms',
      component: RoomsView,
      // Protege a rota: só permite acesso se estiver autenticado
      meta: { requiresAuth: true }
    },
    {
      path: '/config-bot', // NOVA ROTA
      name: 'ConfigBot',
      component: ConfigBotView,
      meta: { requiresAuth: true }
    },
    {
      path: '/',
      redirect: '/login'
    }
  ]
  
const router = createRouter({
  history: createWebHistory(),
  routes
})
  
// Guard global: verifica autenticação antes de entrar em rotas protegidas
router.beforeEach((to, from, next) => {
  const authStore = useAuthStore()
    
  // Carrega dados do localStorage se ainda não foram carregados
  if (!authStore.user) {
    authStore.loadFromStorage()
  }
  
  // Se a rota requer autenticação e o usuário não está autenticado
  if (to.meta.requiresAuth && !authStore.isAuthenticated()) {
    // Redireciona para login
    next('/login')
  } else {
    next()
  }
})
  
export default router