FROM dunglas/frankenphp:1-php8.3 AS frankenphp_upstream

# Base FrankenPHP image
FROM frankenphp_upstream AS frankenphp_base
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
	acl \
    cron \
	&& rm -rf /var/lib/apt/lists/*

RUN set -eux; \
	install-php-extensions \
    @composer \
    pcntl \
    apcu \
    intl \
    opcache \
    pdo_pgsql \
;

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

COPY --link frankenphp-docker/conf.d/app.ini $PHP_INI_DIR/conf.d/
COPY --link --chmod=755 frankenphp-docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY --link --chmod=755 frankenphp-docker/docker-entrypoint.dev.sh /usr/local/bin/docker-entrypoint-dev
COPY --link frankenphp-docker/Caddyfile /etc/caddy/Caddyfile

# Add crontab file in the cron directory
COPY --link --chmod=0644 frankenphp-docker/crontab /etc/cron.d/cron
RUN touch /var/log/cron.log

ENTRYPOINT ["docker-entrypoint"]
HEALTHCHECK CMD curl --fail http://localhost:2019/metrics || exit 1
CMD [ "php", "artisan", "octane:frankenphp", "--caddyfile", "/etc/caddy/Caddyfile", "--host", "localhost", "--https", "--http-redirect", "--port", "443", "--admin-port", "2019" ]

# Dev FrankenPHP image
FROM frankenphp_base AS frankenphp_dev

ENV XDEBUG_MODE=off

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

RUN set -eux; \
	install-php-extensions  \
    xdebug \
	;

# Install Node.js
RUN mkdir /usr/local/nvm
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSION 20.16.0
RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default \
    ;

ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

ENTRYPOINT ["docker-entrypoint-dev"]
COPY --link frankenphp-docker/conf.d/app.dev.ini $PHP_INI_DIR/conf.d/

CMD [ "php", "artisan", "octane:frankenphp", "--caddyfile", "/etc/caddy/Caddyfile", "--host", "localhost", "--https", "--http-redirect", "--port", "443", "--admin-port", "2019", "--workers", "1", "--max-requests", "1", "--watch" ]

FROM node:20-alpine as node_base

WORKDIR /app

COPY --link . .

RUN npm ci && npm run build

# Prod FrankenPHP image
FROM frankenphp_base AS frankenphp_prod

ENV APP_ENV=production

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY --link frankenphp-docker/conf.d/app.prod.ini $PHP_INI_DIR/conf.d/

# copy sources
COPY --link . .

RUN set -eux; \
	composer install --no-cache --prefer-dist --no-dev --no-progress \
    ;

COPY --link --from=node_base /app/public/build/ public/build

RUN rm -Rf frankenphp-docker/

RUN set -eux; \
    mkdir -p storage/app/public storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs; \
	php artisan optimize;
