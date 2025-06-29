#!/bin/sh
set -e

if echo "$@" | grep -qE '(frankenphp|php|artisan)'; then
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
    if ! grep -q -P "DB_URL=.*" .env; then
        sed -i "22s/$/\nDB_URL=pgsql:\/\/app:!ChangeMe!@database:5432\/app\n/" .env
        sed -iE "s/^DB_CONNECTION=\(.*\)/# DB_CONNECTION=\1/" .env
    fi

    php artisan key:generate
  fi

  if [ "$APP_ENV" = "production" ]; then
    service cron start
  fi

  if grep -q ^DB_URL= .env; then
    echo 'Waiting for database to be ready...'
    ATTEMPTS_LEFT_TO_REACH_DATABASE=60
    until [ $ATTEMPTS_LEFT_TO_REACH_DATABASE -eq 0 ] || DATABASE_ERROR=$(php artisan db:show 2>&1); do
      if [ $? -eq 255 ]; then
        # If the Doctrine command exits with 255, an unrecoverable error occurred
        ATTEMPTS_LEFT_TO_REACH_DATABASE=0
        break
      fi
      sleep 1
      ATTEMPTS_LEFT_TO_REACH_DATABASE=$((ATTEMPTS_LEFT_TO_REACH_DATABASE - 1))
      echo "Still waiting for database to be ready... Or maybe the database is not reachable. $ATTEMPTS_LEFT_TO_REACH_DATABASE attempts left."
    done

    if [ $ATTEMPTS_LEFT_TO_REACH_DATABASE -eq 0 ]; then
      echo 'The database is not up or not reachable:'
      echo "$DATABASE_ERROR"
      exit 1
    else
      echo 'The database is now ready and reachable'
    fi

    if [ "$( find ./database/migrations -iname '*.php' -print -quit )" ]; then
      php artisan migrate --force
    fi
  fi

  echo 'Laravel ready!'
fi

exec docker-php-entrypoint "$@"
