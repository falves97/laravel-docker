#!/bin/sh
set -e

if [ "$1" = 'frankenphp' ] || [ "$1" = 'php' ] || [ "$1" = 'artisan' ]; then
  # Install the project the first time PHP is started
  # After the installation, the following block can be deleted
  if [ ! -f composer.json ]; then
    rm -Rf tmp/
    composer create-project laravel/laravel --stability stable --prefer-dist --no-progress --no-interaction --no-install --no-scripts tmp
    cd tmp

    # Install octane
    composer require laravel/octane
    php artisan octane:install --server=frankenphp

    # Necessary for --watch option
    npm install --save-dev chokidar

    rm -f .gitignore README.md
    cp -Rp . ..
    cd ..
    rm -Rf tmp/
  fi

  if [ -z "$(ls -A 'vendor/' 2>/dev/null)" ]; then
    composer install --prefer-dist --no-progress --no-interaction
  fi

  if [ -z "$(ls -A 'node_modules/' 2>/dev/null)" ] && [ -z "$(ls -A 'public/build/' 2>/dev/null)" ]; then
    npm install
  fi

  if [ ! -f ".env" ]; then
    cp .env.example .env

    # Comment out the following lines if you want to use the default .env.example
    sed -i "s/.*DB_CONNECTION=.*/DB_CONNECTION=null/g" .env
    sed -i "s/.*SESSION_DRIVER=.*/SESSION_DRIVER=file/g" .env

    php artisan key:generate
  fi

  if [ "$APP_ENV" = "production" ]; then
    service cron start
  fi

  echo 'Laravel ready!'
fi

exec docker-php-entrypoint "$@"
