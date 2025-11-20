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

## 4. Configuração do Bot (API Config)
    - Backend:
        - Atualizei o modelo ApiConfig em backend/app/models/api_config.rb:
            - Removido belongs_to :user (API key é global para todos os usuários)
            - Implementado padrão singleton com método self.current que retorna primeira configuração ou cria nova
            - Método has_api_key? para verificar se há API key configurada
            - API key armazenada em texto plano (sem criptografia) para facilitar configuração em projeto de teste
        - Criei migrations para ajustar estrutura da tabela:
            - Remove user_id de api_configs (API key é única para todo o sistema)
            - Torna api_key e llm_model nullable (text) para permitir configuração parcial
            - Remove coluna encrypted_api_key (não utilizada)
        - Criei o ApiConfigController em backend/app/controllers/api_config_controller.rb com os métodos:
            - show: retorna configuração atual (GET /api_config), não expõe API key completa, apenas indica se existe
            - create: salva ou atualiza API key e modelo (POST /api_config), valida API key fazendo requisição de teste à OpenAI
            - update: atualiza apenas o modelo LLM (PATCH /api_config), sem validar API key novamente
            - models: lista modelos disponíveis da OpenAI (GET /api_config/models), filtra apenas modelos GPT de chat (gpt-*)
        - Criei o OpenaiService em backend/app/services/openai_service.rb com métodos:
            - initialize: recebe API key como parâmetro
            - list_models: faz requisição GET /v1/models e retorna lista de IDs de modelos
            - generate_response: gera resposta usando OpenAI (suporta chat/completions e completions)
            - validate_api_key: valida API key fazendo requisição de teste
            - is_chat_model?: detecta se modelo é de chat (gpt-*, o1-*, claude-*, etc) ou completion (davinci-002, etc)
            - generate_chat_completion: usa endpoint /v1/chat/completions para modelos de chat
            - generate_completion: usa endpoint /v1/completions para modelos antigos
        - Adicionei gem "faraday" no Gemfile para fazer requisições HTTP à API OpenAI
        - Configurei ActiveJob em backend/config/application.rb com queue_adapter :async para processar respostas do bot em background
    - Frontend:
        - Criei o arquivo frontend/src/stores/apiConfig.js com store Pinia que gerencia configuração da API:
            - State: config (configuração atual), models (lista de modelos), loading, saving, error, hasApiKey (computed)
            - Actions: fetchConfig (busca configuração atual), saveConfig (salva API key e modelo), updateModel (atualiza apenas modelo), fetchModels (lista modelos da OpenAI)
            - Getters: currentModel (retorna modelo atual), hasApiKey (verifica se há API key)
        - Criei o arquivo frontend/src/views/ConfigBotView.vue com:
            - Tela completa de configuração do bot
            - Seção de API Key: campo para inserir/editar API key com toggle para mostrar/ocultar, validação ao salvar, status de sucesso quando configurada
            - Seção de Modelo LLM: select com modelos disponíveis, carregamento automático após salvar API key, alerta quando modelo não é de chat
            - Avisos informativos sobre armazenamento da API key em texto plano (não é boa prática para produção, mas facilita configuração em projeto de teste)
            - Card "Como funciona?" com instruções de uso
            - Botão "Salvar Modelo" para persistir seleção
            - Navegação de volta para /rooms
        - Adicionei rota /config-bot em frontend/src/router/index.js com guard de autenticação
        - Adicionei botão "Configurar @Bot" na barra superior de RoomsView.vue que navega para /config-bot

## 5. Integração com OpenAI e Bot Automático
    - Backend:
        - Criei o ProcessBotResponseJob em backend/app/jobs/process_bot_response_job.rb:
            - ActiveJob que processa respostas do bot em background
            - Detecta quando mensagem contém "@bot" (case-insensitive)
            - Busca configuração atual da API (ApiConfig.current)
            - Valida se há API key e modelo configurados
            - Chama OpenaiService para gerar resposta baseada no tipo de modelo (chat ou completion)
            - Cria mensagem do bot associada ao usuário "Bot" (criado automaticamente se não existir)
            - Faz broadcast da mensagem do bot via ActionCable para todos os clientes da sala
            - Atualiza contador de mensagens via broadcast
            - Tratamento de erros com logging sem quebrar o fluxo
        - Atualizei MessagesController#create para disparar ProcessBotResponseJob quando detecta "@bot" na mensagem:
            - Verifica se conteúdo da mensagem contém "@bot" (case-insensitive)
            - Chama ProcessBotResponseJob.perform_later de forma assíncrona
        - OpenaiService suporta dois tipos de modelos:
            - Modelos de chat (gpt-*, o1-*, claude-*): usa endpoint /v1/chat/completions com formato messages array
            - Modelos de completion (davinci-002, etc): usa endpoint /v1/completions com formato prompt string
            - Detecção automática do tipo de modelo baseada no nome
        - Configuração de timeout de 30 segundos para requisições à OpenAI
        - Tratamento de erros da API OpenAI com mensagens descritivas