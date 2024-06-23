#!/bin/sh
set -e

if [ ! -f "node/localhost.key" ]; then
  cd node
  openssl req -newkey rsa:4096 \
              -x509 \
              -sha256 \
              -days 3650 \
              -nodes \
              -out localhost.crt \
              -keyout localhost.key \
              -subj "/C=BR/ST=Estado/L=Cidade/O=Company Name/OU=Unity Compane Name/CN=localhost"
  cd ..
fi

if [ "$1" = 'yarn' ]; then

  if [ -z "$(ls -A 'node_modules/' 2>/dev/null)" ] && [ -f "package.json" ]; then
    if [ $NODE_ENV = "development" ]; then
      yarn --non-interactive
    else
      yarn --production --frozen-lockfile --non-interactive
    fi
  fi

fi

exec "$@"