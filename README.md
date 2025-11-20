# ChatBot Challenge - Sistema de Chat de Atendimento

Sistema de chat em tempo real similar ao Chatwoot, desenvolvido com Ruby on Rails 7 (backend) e Vue 3 + Vite (frontend).

## 🚀 Tecnologias

- **Backend**: Ruby on Rails 7, PostgreSQL, Redis, ActionCable
- **Frontend**: Vue 3, Vite, Vuetify, Pinia, Axios
- **Containerização**: Docker, Docker Compose

## 📋 Pré-requisitos

- Docker e Docker Compose instalados
- Make (opcional, mas recomendado)

## 🛠️ Como executar

### Setup inicial (primeira vez)
- make setup
- make up     estará disponível em: (http://localhost:5173)

### Outros comandos úteis
- make down          # Parar todos os serviços
- make logs          # Ver logs de todos os serviços
- make api-logs      # Ver logs apenas do backend
- make frontend-logs # Ver logs apenas do frontend
- make rails-console # Abrir console do Rails
- make restart       # Reiniciar todos os serviços
- make clean         # Parar e remover volumes (limpar banco)

### Autenticação
- `POST /sessions` - Login

### Salas (Rooms)
- `GET /rooms` - Lista todas as salas (abertas e fechadas)
- `POST /rooms` - Cria nova sala
- `GET /rooms/:id` - Detalhes de uma sala
- `PATCH /rooms/:id/close` - Marca sala como concluída
- `DELETE /rooms/:id` - Exclui sala permanentemente

### Mensagens
- `GET /rooms/:room_id/messages` - Lista mensagens de uma sala
- `POST /rooms/:room_id/messages` - Envia nova mensagem

### Configuração do Bot
- `GET /api_config` - Retorna configuração atual
- `POST /api_config` - Salva API key e modelo
- `PATCH /api_config` - Atualiza apenas o modelo
- `GET /api_config/models` - Lista modelos disponíveis da OpenAI

**Nota sobre autenticação**: Todos os endpoints (exceto `/sessions`) requerem token JWT no header `Authorization: Bearer <token>`

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
├── backend/          # Aplicação Rails
│   ├── app/
│   │   ├── controllers/
│   │   ├── models/
│   │   ├── channels/    # ActionCable
│   │   ├── jobs/        # ActiveJob (bot responses)
│   │   └── services/    # OpenaiService
│   └── config/
├── frontend/         # Aplicação Vue
│   ├── src/
│   │   ├── components/
│   │   ├── views/
│   │   ├── stores/      # Pinia stores
│   │   └── router/
│   └── package.json
├── docker-compose.yml
└── Makefile