#!/bin/sh
set -e

if [ "$1" = 'frankenphp' ] || [ "$1" = 'php' ] || [ "$1" = 'artisan' ]; then
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
    if [ "$( find ./database/migrations -iname '*.php' -print -quit )" ]; then
      php artisan migrate --no-interaction
    fi
  fi

  if [ ! -f ".env" ]; then
    cp .env.example .env

    # Install octane
    composer require laravel/octane
    php artisan octane:install --server=frankenphp

    php artisan key:generate
  fi

fi

exec docker-php-entrypoint "$@"
