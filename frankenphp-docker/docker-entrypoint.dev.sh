#!/bin/sh
set -e

# Start cron service
service cron start

if [ "$1" = 'frankenphp' ] || [ "$1" = 'php' ] || [ "$1" = 'artisan' ]; then
    if [ ! -f "frankenphp-docker/certs/localhost.key" ]; then
        cd frankenphp-docker/certs
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
        composer create-project laravel/laravel tmp --prefer-dist --no-progress --no-interaction --no-install --no-scripts

        cd tmp
        cp -Rp . ..
        cd ..
        rm -Rf tmp/
    fi

    if [ -z "$(ls -A 'vendor/' 2>/dev/null)" ]; then
        composer install --prefer-dist --no-progress --no-interaction
    fi

    setfacl -R -m u:www-data:rwX -m u:"$(whoami)":rwX storage
    setfacl -dR -m u:www-data:rwX -m u:"$(whoami)":rwX storage

    if grep -q ^DB_CONNECTION= .env; then
        if [ "$(find ./database/migrations -iname '*.php' -print -quit)" ]; then
            php artisan migrate --no-interaction
        fi
    fi

    if [ ! -f ".env" ]; then
        cp .env.example .env
        sed -i "s/DB_CONNECTION=sqlite/DB_CONNECTION=pgsql/g" .env
        sed -i "s/# DB_HOST=127.0.0.1/DB_HOST=database/g" .env
        sed -i "s/# DB_PORT=3306/DB_PORT=5432/g" .env
        sed -i "s/# DB_DATABASE=laravel/DB_DATABASE=app/g" .env
        sed -i "s/# DB_USERNAME=root/DB_USERNAME=app/g" .env
        sed -i "s/# DB_PASSWORD=/DB_PASSWORD=!ChangeMe!/g" .env

        # Install octane
        composer require laravel/octane
        php artisan octane:install --server=frankenphp

        php artisan key:generate

        # Necessary for --watch option
        npm install --save-dev chokidar
    fi

fi

exec docker-php-entrypoint "$@"
