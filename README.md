# ChatBot Challenge - Sistema de Chat de Atendimento

Sistema de chat em tempo real similar ao Chatwoot, desenvolvido com Ruby on Rails 7 (backend) e Vue 3 + Vite (frontend).

## 🚀 Tecnologias

- **Backend**: Ruby on Rails 7, PostgreSQL, Redis, ActionCable
- **Frontend**: Vue 3, Vite, Vuetify, Pinia, Axios
- **Containerização**: Docker, Docker Compose

## 📋 Pré-requisitos

- **Docker Desktop** instalado e rodando
  - Windows: [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
  - Linux: Docker Engine + Docker Compose
  - macOS: [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)
- **Git** instalado
- **Make** (opcional, mas recomendado)

## 🛠️ Como executar

### Passo a passo completo

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/derektsc/ChatBotChallenge.git
   cd ChatBotChallenge
   ```

2. **Certifique-se de que o Docker Desktop está rodando**

3. **Execute o setup inicial (primeira vez):**
   ```bash
   make setup
   ```
   Ou sem Make:
   ```bash
   docker compose build
   ```

4. **Suba os serviços:**
   ```bash
   make up
   ```
   Ou sem Make:
   ```bash
   docker compose up -d
   ```

5. **Acesse a aplicação:**
   - http://localhost:5173

### Outros comandos úteis

```bash
make down          # Parar todos os serviços
make logs          # Ver logs de todos os serviços
make api-logs      # Ver logs apenas do backend
make frontend-logs # Ver logs apenas do frontend
make rails-console # Abrir console do Rails
make restart       # Reiniciar todos os serviços
make clean         # Parar e remover volumes (limpar banco)
```

## Escolhas Tecnicas

### Backend - Ruby on Rails 7
- **ActionCable nativo**: Rails já inclui ActionCable para WebSockets, facilitando comunicação em tempo real
- **ActiveJob**: Sistema de jobs em background integrado, perfeito para processar respostas do bot sem bloquear requisições
- **API Mode**: Rails 7 em modo API é leve e focado em JSON, ideal para backends.

### Frontend - Vue 3 + Vite
- **Vue 3 Composition API**: Sintaxe moderna e reativa, facilitando gerenciamento de estado
- **Vite**: Build tool extremamente rápido
- **Vuetify**: Framework de componentes Material Design, acelera desenvolvimento de UI
- **Pinia**: Gerenciamento de estado simples e intuitivo

### PostgreSQL
- **Relacional**: Estrutura de dados bem definida (users, rooms, messages)
- **Performance**: Excelente para queries complexas e relacionamentos
- **Maturidade**: Banco de dados confiável e amplamente suportado

### Redis
- **ActionCable**: Necessário para o ActionCable funcionar (gerencia conexões WebSocket)
- **Performance**: Banco em memória, extremamente rápido para pub/sub
- **Escalabilidade**: Permite múltiplos servidores Rails compartilharem conexões WebSocket
- **Pub/Sub nativo**: Suporte nativo a publish/subscribe, perfeito para tempo real

### Docker & Docker Compose
- **Isolamento**: Cada serviço roda em seu próprio container
- **Reprodutibilidade**: Mesmo ambiente em qualquer máquina (Windows, Linux, macOS)
- **Facilidade**: Um único comando (`docker compose up`) inicia toda a aplicação
- **Desenvolvimento**: Hot-reload automático, sem necessidade de reinstalar dependências

### JWT para Autenticação
- **Stateless**: Não precisa armazenar sessões no servidor
- **Escalável**: Tokens podem ser validados em qualquer servidor
- **Seguro**: Tokens assinados e podem expirar
- **WebSocket**: Facilita autenticação de conexões WebSocket

### ActiveJob para Respostas do Bot
- **Não bloqueia**: Requisições HTTP retornam imediatamente
- **Background**: Processamento assíncrono de chamadas à API OpenAI
- **Confiável**: Sistema integrado do Rails com retry automático
- **Flexível**: Pode trocar para Sidekiq, Resque, etc. em produção

## 📡 Endpoints da API

### Health Check
- `GET /up` - Verifica se a aplicação está rodando (retorna 200 se OK)

### WebSocket
- `WS /cable` - Conexão WebSocket para ActionCable (comunicação em tempo real)

### Autenticação
- `POST /sessions` - Login (cria/retorna usuário e token JWT)
  - Body: `{ "name": "Nome do Usuário" }`
  - Response: `{ "user": {...}, "token": "jwt_token" }`

### Salas (Rooms)
- `GET /rooms` - Lista todas as salas (abertas e fechadas)
  - Response: `{ "open_rooms": [...], "closed_rooms": [...] }`
- `POST /rooms` - Cria nova sala
  - Body: `{ "title": "Nome da Sala" }`
  - Response: `{ "id": 1, "title": "...", "status": "open", ... }`
- `GET /rooms/:id` - Detalhes de uma sala específica
- `PATCH /rooms/:id/close` - Marca sala como concluída (status: "closed")
- `DELETE /rooms/:id` - Exclui sala permanentemente

### Mensagens
- `GET /rooms/:room_id/messages` - Lista mensagens de uma sala
  - Response: `{ "room": {...}, "messages": [...] }`
- `POST /rooms/:room_id/messages` - Envia nova mensagem
  - Body: `{ "content": "Texto da mensagem" }`
  - Response: `{ "id": 1, "content": "...", "user": {...}, ... }`
  - **Nota**: Se a mensagem contém "@bot", o bot responde automaticamente

### Configuração do Bot
- `GET /api_config` - Retorna configuração atual (API key e modelo)
  - Response: `{ "id": 1, "llm_model": "gpt-4", "has_api_key": true, ... }`
- `POST /api_config` - Salva API key e modelo LLM
  - Body: `{ "api_key": "sk-...", "llm_model": "gpt-4" }`
- `PATCH /api_config` - Atualiza apenas o modelo LLM
  - Body: `{ "llm_model": "gpt-3.5-turbo" }`
- `GET /api_config/models` - Lista modelos disponíveis da OpenAI
  - Response: `{ "models": ["gpt-4", "gpt-3.5-turbo", ...] }`

**Nota sobre autenticação**: Todos os endpoints (exceto `/sessions` e `/up`) requerem token JWT no header `Authorization: Bearer <token>`

## 🤖 Funcionalidades do Bot

Quando uma mensagem contém "@bot", o sistema:
1. Detecta a menção ao bot
2. Processa a resposta em background via ActiveJob
3. Chama a API da OpenAI para gerar resposta
4. Envia a resposta automaticamente para o chat

**Suporte a diferentes tipos de modelos**:
- Modelos de chat (gpt-*, o1-*, claude-*): usa `/v1/chat/completions`
- Modelos de completion (davinci-002, etc): usa `/v1/completions`

## ⚙️ Configuração

### API Key da OpenAI

A API key é armazenada em texto plano no banco de dados. **Esta não é uma boa prática para produção**, mas foi implementada desta forma para facilitar a configuração neste projeto de teste/estudo.

Em produção, recomenda-se:
- Usar variáveis de ambiente
- Secrets management (AWS Secrets Manager, HashiCorp Vault, etc)
- Criptografia adequada da API key

## 📁 Estrutura do Projeto
ChatBotChallenge/
- backend/  (Rails)
  - app/
    - controllers/
    - models/
    - channels/   (ActionCable)
    - jobs/       (ActiveJob: respostas do bot)
    - services/   (OpenaiService)
  - config/

- frontend/ (Vue)
  - src/
    - components/
    - views/
    - stores/     (Pinia)
    - router/
  - package.json
- docker-compose.yml
- Makefile