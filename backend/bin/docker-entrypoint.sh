#!/bin/sh
set -e

# Instala gems se necessário
bundle check || bundle install

exec "$@"