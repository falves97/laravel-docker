#!/bin/sh
set -e

if [ "$1" = 'frankenphp' ] || [ "$1" = 'php' ] || [ "$1" = 'artisan' ]; then
    if [ "$APP_ENV" != 'production' ]; then
        if [ ! -f "frankenphp-docker/certs/localhost.key" ]; then
            cd frankenphp/certs
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

            rm -f .gitignore
            cp -Rp . ..
            cd ..
            rm -Rf tmp/
        fi

        if [ -z "$(ls -A 'vendor/' 2>/dev/null)" ]; then
            composer install --prefer-dist --no-progress --no-interaction
        fi

        if [ -z "$(ls -A 'node_modules/' 2>/dev/null)" ]; then
            npm install
        fi

        if [ ! -f ".env.testing" ]; then
            cp .env.example .env.testing
            sed -i "s/.*APP_ENV=.*/APP_ENV=testing/g" .env.testing
            sed -i "s/.*DB_DATABASE=.*/DB_DATABASE=test/g" .env.testing
            sed -i "s/.*DB_USERNAME=.*/DB_USERNAME=test/g" .env.testing
            sed -i "s/.*DB_PASSWORD=.*/DB_PASSWORD=test/g" .env.testing

            php artisan key:generate --env=testing
        fi

        if [ ! -f ".env" ]; then
            sed -i "s/.*DB_CONNECTION=.*/DB_CONNECTION=$DATABASE_CONNECTION/g" .env.example
            sed -i "s/.*DB_HOST=.*/DB_HOST=$DATABASE_HOST/g" .env.example
            sed -i "s/.*DB_PORT=.*/DB_PORT=$DATABASE_PORT/g" .env.example
            sed -i "s/.*DB_DATABASE=.*/DB_DATABASE=$DATABASE_DATABASE/g" .env.example
            sed -i "s/.*DB_USERNAME=.*/DB_USERNAME=$DATABASE_USERNAME/g" .env.example
            sed -i "s/.*DB_PASSWORD=.*/DB_PASSWORD=$DATABASE_PASSWORD/g" .env.example
            cp .env.example .env

            php artisan key:generate
        fi
    else
        php artisan key:generate
        php artisan optimize
        php artisan optimize:clear
        sync
    fi

    setfacl -R -m u:www-data:rwX -m u:"$(whoami)":rwX storage
    setfacl -dR -m u:www-data:rwX -m u:"$(whoami)":rwX storage

    if grep -q ^DB_CONNECTION= .env; then
        if [ "$(find ./database/migrations -iname '*.php' -print -quit)" ]; then
            php artisan migrate --no-interaction --force
        fi
    fi

    echo 'Laravel ready!'
fi

# Start cron service
service cron start

exec docker-php-entrypoint "$@"
