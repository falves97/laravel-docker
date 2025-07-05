#syntax=docker/dockerfile:1

# Versions
ARG NODE_VERSION=22.17.0

FROM dunglas/frankenphp:1-php8.4 AS frankenphp_upstream

# Node.js base image
FROM node:${NODE_VERSION}-slim AS node_base

# Base FrankenPHP image
FROM frankenphp_upstream AS frankenphp_base

WORKDIR /app

ENV HOST=localhost

# Install Node.js
COPY --link --from=node_base /usr/local/ /usr/local/
COPY --link --from=node_base /opt/ /opt/

RUN apt-get update && apt-get install -y --no-install-recommends \
	acl \
    cron \
	file \
	gettext \
	git \
	&& rm -rf /var/lib/apt/lists/*

RUN set -eux; \
	install-php-extensions \
        @composer \
        pcntl \
        apcu \
        intl \
        opcache \
        zip \
    ;

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

RUN install-php-extensions pdo_pgsql

COPY --link frankenphp/conf.d/10-app.ini $PHP_INI_DIR/app.conf.d/
COPY --link --chmod=755 frankenphp/docker-entrypoint.sh /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]

HEALTHCHECK CMD curl --fail http://localhost:2019/metrics || exit 1
CMD php artisan octane:frankenphp --host=$HOST --port=443 --https --http-redirect

# Dev FrankenPHP image
FROM frankenphp_base AS frankenphp_dev

ENV XDEBUG_MODE=off

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

RUN set -eux; \
	install-php-extensions  \
      xdebug \
	;

COPY --link frankenphp/conf.d/20-app.dev.ini $PHP_INI_DIR/conf.d/

CMD php artisan octane:frankenphp --host=$HOST --port=443 --https --http-redirect --workers=1 --max-requests=1 --watch --poll

# Prod FrankenPHP image
FROM frankenphp_base AS frankenphp_prod

ENV APP_ENV=production
ENV APP_DEBUG=false

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY --link frankenphp/conf.d/20-app.prod.ini $PHP_INI_DIR/app.conf.d/

# Add crontab file in the cron directory
COPY --link --chmod=0644 frankenphp/crontab /etc/cron.d/cron
RUN touch /var/log/cron.log

# prevent the reinstallation of vendors at every changes in the source code
COPY --link composer.* package*.json ./

RUN set -eux; \
	composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress && \
    npm ic \
    ;

# copy sources
COPY --link . ./
RUN rm -Rf frankenphp/

RUN npm run build && rm -rf node_modules/

RUN set -eux; \
    mkdir -p  \
        bootstrap/cache  \
        storage/app/public storage/app/private  \
        storage/framework/cache/data  \
        storage/framework/sessions  \
        storage/framework/views storage/logs; \
	composer dump-autoload --classmap-authoritative --no-dev; \
    sync \
    ;
