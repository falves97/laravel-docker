#!/bin/sh
set -e

if [ ! -f "node/certs/localhost.key" ]; then
  cd node/certs
  openssl req -newkey rsa:4096 \
              -x509 \
              -sha256 \
              -days 3650 \
              -nodes \
              -out localhost.crt \
              -keyout localhost.key \
              -subj "/C=BR/ST=Estado/L=Cidade/O=Company Name/OU=Unity Compane Name/CN=localhost"
  cd ../..
fi

if [ "$1" = 'yarn' ]; then
  if [ -z "$(ls -A 'node_modules/' 2>/dev/null)" ] && [ -f "package.json" ]; then
      yarn --non-interactive
  fi
fi

exec "$@"