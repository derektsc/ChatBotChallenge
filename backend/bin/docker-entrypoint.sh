#!/bin/sh
set -e

# Instala gems se necessário
bundle check || bundle install

# Cria diretórios se não existirem (garantia extra)
mkdir -p tmp/pids tmp/cache tmp/sockets log

# Aguarda o banco estar pronto (máximo 30 segundos)
echo "Aguardando banco de dados..."
for i in $(seq 1 30); do
  if bundle exec rails runner "ActiveRecord::Base.connection" 2>/dev/null; then
    echo "Banco de dados conectado!"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "Aviso: Banco de dados não está respondendo, mas continuando..."
  else
    sleep 1
  fi
done

# Cria banco e executa migrations (ignora erros se já existir)
echo "Configurando banco de dados..."
bundle exec rails db:create 2>/dev/null || true
bundle exec rails db:migrate 2>/dev/null || true

# Executa o comando passado (normalmente o Puma)
exec "$@"