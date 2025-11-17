Este documento descreve a ordem de desenvolvimento e como implementar cada funcionalidade:

## Estrutura Inicial do Projeto

### Setup Docker e Ambiente
- Dockerfile para backend (Rails) e frontend (Vue)
- docker-compose.yml com serviços: api, frontend, db (PostgreSQL), redis
- Makefile com comandos para subir/derrubar ambiente
- Configuração de CORS no backend (rack-cors)

### Criação das tabelas (dentro do container api):
    bin/rails g model User name:string:index
    bin/rails g model Room channel_name:string:index title:string status:string
    bin/rails g model Message content:text user:references room:references
    bin/rails g model ApiConfig api_key:string llm_model:string
- **User**: Armazena usuários do sistema (apenas nome)
- **Room**: Salas de atendimento (channel_name, title, status: open/closed)
- **Message**: Mensagens dentro das salas (content, user_id, room_id)
- **ApiConfig**: Configurações da API OpenAI (api_key, llm_model)

**Acessar o banco:**
docker exec -it chatbotchallenge-db-1 psql -U chatwoot -d chatwoot_development

**Comandos úteis:**
-- Listar todas as tabelas
\dt

-- Ver estrutura de uma tabela
\d users
\d rooms
\d messages

-- Ver todos os usuários
SELECT * FROM users;

-- Ver todas as salas
SELECT * FROM rooms;---

## 1. Login e autenticação (JWT) por nome
    - Backend (ruby on rails): endpoint que recebe um name, cria (ou reutiliza) um User e devolve os dados em JSON.
        - Adicionei a gema "jwt" no Gemfile para autenticação via token
        - Criei o arquivo backend/app/controllers/concerns/jwt_authenticatable.rb com o concern que valida tokens JWT em todas as requisições, extrai o token do header Authorization e identifica o usuário atual
        - Criei o arquivo backend/app/models/concerns/jwt_token.rb com o método generate_jwt_token que cria tokens JWT com expiração de 24 horas
        - Atualizei o modelo User para incluir o concern JwtToken
        - Criei o SessionsController em backend/app/controllers/sessions_controller.rb com o método create que recebe um nome, cria ou encontra o usuário e retorna user_id, name e token JWT
        - Configurei o ApplicationController para exigir autenticação por padrão em todas as rotas, exceto SessionsController que usa skip_before_action
        - Adicionei a rota POST /sessions em config/routes.rb
        - Configurei CORS em backend/config/initializers/cors.rb para permitir requisições do frontend, descomentei a gem rack-cors no Gemfile

    - Frontend (vue): tela de login em Vue onde o usuário digita o nome, faz a requisição ao backend, guarda o usuário logado (Pinia) e redireciona para uma tela de “Lista de Salas”
        - Instalei as dependências: vue-router, pinia, axios, vuetify, @mdi/font, @rails/actioncable
        - Criei o arquivo frontend/src/router/index.js com as rotas /login e /rooms, incluindo guards de autenticação que redirecionam para login se não autenticado
        - Criei o arquivo frontend/src/stores/auth.js com o store Pinia que gerencia autenticação, faz login via POST /sessions, guarda token JWT no localStorage, configura interceptors do axios para enviar token em todas as requisições e trata erros 401
        - Criei o arquivo frontend/src/views/LoginView.vue com tela de login usando Vuetify, formulário com validação, tratamento de erros e redirecionamento para /rooms após login
        - Atualizei frontend/src/App.vue para usar v-app (obrigatório para Vuetify) e RouterView
        - Configurei Vuetify em frontend/src/main.js com temas dark e light, instalando Pinia e Vue Router

## 2. Lista de salas (Rooms)
    - Backend
        - Atualizei o modelo Room em backend/app/models/room.rb com validações, relacionamento has_many :messages, scopes para open/closed, callback before_validation para gerar channel_name único com UUID
        - Criei o RoomsController em backend/app/controllers/rooms_controller.rb com os métodos:
            - index: lista todas as salas (abertas e fechadas) separadas por status
            - create: cria nova sala e faz broadcast via ActionCable
            - close: marca sala como concluída (PATCH /rooms/:id/close) e faz broadcast
            - destroy: exclui sala permanentemente (DELETE /rooms/:id) e faz broadcast
            - show: retorna detalhes de uma sala
        - Adicionei rotas em config/routes.rb: resources :rooms com member route :close
        - Criei o RoomsChannel em backend/app/channels/application_cable/rooms_channel.rb para broadcast de eventos de salas
        - Configurei ActionCable em backend/config/environments/development.rb com allowed_request_origins para permitir conexões WebSocket do frontend e disable_request_forgery_protection = true
        - Adicionei rota mount ActionCable.server => '/cable' em config/routes.rb
    - Frontend
        - Criei o arquivo frontend/src/stores/rooms.js com store Pinia que gerencia estado das salas, métodos fetchRooms, createRoom, closeRoom, deleteRoom, getters openRooms e closedRooms
        - Criei o arquivo frontend/src/views/RoomsView.vue com:
            - Tabs para alternar entre salas ativas e concluídas
            - Botão flutuante para criar nova sala
            - Menu de ações em cada sala (concluir/excluir)
            - Formatação de datas (Hoje, Ontem, etc)
            - Conexão ActionCable para receber atualizações em tempo real das salas
            - Tratamento de eventos room_created, room_closed, room_deleted
        - Criei o arquivo frontend/src/stores/theme.js para gerenciar tema light/dark com localStorage
        - Configurei tema no main.js usando vuetify.theme.change()
        - Adicionei botão de toggle de tema na barra superior
        - Criei o arquivo frontend/src/types/actioncable.d.ts para tipos TypeScript do ActionCable
        - Instalei @rails/actioncable via npm
        - Configurei conexão WebSocket dinâmica baseada na URL do backend Rails


## 3. Visualização e envio de mensagens
    - Backend:
        - Criei o MessagesController em backend/app/controllers/messages_controller.rb com os métodos:
            - index: lista todas as mensagens de uma sala (GET /rooms/:room_id/messages), ordenadas por data de criação (mais antigas primeiro), inclui dados do usuário (user) via includes(:user) para evitar N+1 queries
            - create: cria nova mensagem (POST /rooms/:room_id/messages), valida conteúdo não vazio, associa ao usuário atual (current_user) e à sala, faz broadcast via ActionCable para todos os clientes conectados à sala usando stream "room_#{room.id}", também faz broadcast do contador de mensagens atualizado no stream "rooms"
            - format_message: método helper privado para formatar dados da mensagem (id, content, user {id, name}, room_id, created_at, updated_at)
        - Adicionei rotas aninhadas em config/routes.rb: resources :messages, only: [:index, :create] dentro de resources :rooms
        - Criei o RoomsChannel em backend/app/channels/rooms_channel.rb (movido de application_cable para o namespace correto) com:
            - subscribed: permite inscrição em sala específica (stream_from "room_#{room.id}") ou no channel geral (stream_from "rooms")
            - unsubscribed: limpeza ao desinscrever
        - Atualizei ApplicationCable::Connection em backend/app/channels/application_cable/connection.rb com:
            - Autenticação JWT via token nos query params ou header Authorization
            - identified_by :current_user para identificar conexões por usuário
            - Método decode_token usando a mesma secret_key do JWT
    - Frontend:
        - Criei o arquivo frontend/src/stores/messages.js com store Pinia completo:
            - State: messages (objeto com roomId como chave), loading, error, sending (por sala), unreadCounts (contador de não lidas por sala), lastReadMessage (última mensagem lida por sala)
            - Actions: fetchMessages (busca mensagens e marca como lidas), sendMessage (envia mensagem e marca como lida), addMessage (adiciona mensagem recebida via ActionCable), markAsRead (marca mensagens como lidas), incrementUnread (incrementa contador de não lidas), clearMessages (limpa mensagens de uma sala)
            - Getters: getMessagesByRoom (retorna mensagens de uma sala), isSending (verifica se está enviando), getUnreadCount (retorna contador de não lidas)
        - Criei o componente frontend/src/components/ChatView.vue com:
            - Cabeçalho do chat mostrando título da sala e status (Ativa/Concluída)
            - Área de mensagens com scroll automático para o final
            - Loading state durante carregamento
            - Mensagem vazia quando não há mensagens
            - Input de mensagem com botão de envio, validação de conteúdo vazio, desabilita botão durante envio
            - Formatação de horário das mensagens (HH:mm)
            - Identificação de mensagens próprias vs de outros usuários
            - Exibição do nome do autor em mensagens de outros usuários
            - Responsivo para mobile e desktop
        - Atualizei frontend/src/views/RoomsView.vue com:
            - Layout de duas colunas: sidebar esquerda (lista de salas) + área de chat à direita
            - Responsividade mobile: sidebar temporária que fecha ao abrir chat, botão de menu para abrir sidebar, botão voltar quando chat está aberto
            - Integração completa com ActionCable:
                - Conexão única reutilizada (cable) com token JWT nos query params
                - Subscription no channel geral "RoomsChannel" para eventos de salas (room_created, room_closed, room_deleted, room_message_count_updated)
                - Subscriptions individuais por sala para receber mensagens em tempo real
                - Inscrição automática em todas as salas ao carregar
                - Inscrição automática em novas salas criadas
            - Badge de notificação de mensagens não lidas em cada sala (v-badge com contador)
            - Atualização automática de contador de mensagens via ActionCable
            - Seleção de sala carrega mensagens e marca como lidas
            - Tela vazia quando nenhuma sala está selecionada com botão para abrir sidebar em mobile
            - Tema dark/light com paletas de cores atualizadas

4. ActionCable (WebSocket)
Backend:
    Channel para cada sala
    Broadcast de novas mensagens
Frontend:
    Conectar ao ActionCable
    Receber mensagens em tempo real
    Notificações visuais

5. Configuração do Bot (OpenAI)
Backend:
    Endpoint GET /api_config/models (listar modelos OpenAI)
    Endpoint POST /api_config (salvar API key e modelo)
    Service para detectar "@bot" e chamar OpenAI
Frontend:
    Tela de configuração
    Input de API key (criptografada)
    Select de modelos