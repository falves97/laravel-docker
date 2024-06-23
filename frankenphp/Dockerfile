FROM dunglas/frankenphp:1-php8.3 AS frankenphp_upstream

# Base FrankenPHP image
FROM frankenphp_upstream AS frankenphp_base

RUN apt-get update && apt-get install -y --no-install-recommends \
	acl \
	&& rm -rf /var/lib/apt/lists/*

RUN set -eux; \
	install-php-extensions \
    @composer \
    apcu \
    opcache \
    pdo_pgsql \
;

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

COPY --link conf.d/app.ini $PHP_INI_DIR/conf.d/
COPY --link --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY --link Caddyfile /etc/caddy/Caddyfile

ENTRYPOINT ["docker-entrypoint"]
CMD [ "frankenphp", "run", "--config", "/etc/caddy/Caddyfile" ]

# Dev FrankenPHP image
FROM frankenphp_base AS frankenphp_dev

ENV APP_ENV=dev XDEBUG_MODE=off

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

RUN set -eux; \
	install-php-extensions \
		xdebug \
	;

COPY --link conf.d/app.dev.ini $PHP_INI_DIR/conf.d/

CMD [ "frankenphp", "run", "--config", "/etc/caddy/Caddyfile", "--watch" ]

# Prod FrankenPHP image
FROM frankenphp_base AS frankenphp_prod

ENV APP_ENV=prod

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY --link conf.d/app.prod.ini $PHP_INI_DIR/conf.d/

# prevent the reinstallation of vendors at every changes in the source code
COPY --link composer.* ./
RUN set -eux; \
	composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress

# copy sources
COPY --link .. ./
RUN rm -Rf node/
RUN rm -Rf frankenphp/

RUN set -eux; \
	php artisan optimize; \
	php artisan optimize:clear; \
	php artisan config:cache; \
	php artisan event:cache; \
	php artisan route:cache; \
	php artisan view:cache;
