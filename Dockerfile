FROM dunglas/frankenphp:1-php8.3 AS frankenphp_upstream

# Base FrankenPHP image
FROM frankenphp_upstream AS frankenphp_base
WORKDIR /app

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

COPY --link frankenphp/conf.d/10-app.ini $PHP_INI_DIR/app.conf.d/
COPY --link --chmod=755 frankenphp/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY --link frankenphp/Caddyfile /etc/caddy/Caddyfile

ENTRYPOINT ["docker-entrypoint"]

HEALTHCHECK CMD curl --fail http://localhost:2019/metrics || exit 1
CMD [ "php", "artisan", "octane:frankenphp", "--caddyfile=/etc/caddy/Caddyfile", "--host=0.0.0.0", "--https", "--http-redirect", "--port=443", "--admin-port=2019" ]

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

ARG NODE_VERSION=22.15.0

RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default \
    ;

ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

COPY --link frankenphp/conf.d/20-app.dev.ini $PHP_INI_DIR/conf.d/

CMD [ "php", "artisan", "octane:frankenphp", "--caddyfile=/etc/caddy/Caddyfile", "--host=0.0.0.0", "--https", "--http-redirect", "--port=443", "--admin-port=2019", "--workers=1", "--max-requests=1", "--watch", "--poll" ]

# Prod FrankenPHP image
FROM frankenphp_base AS frankenphp_prod

ENV APP_ENV=production
ENV APP_DEBUG=false

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY --link frankenphp/conf.d/20-app.prod.ini $PHP_INI_DIR/app.conf.d/

# Add crontab file in the cron directory
COPY --link --chmod=0644 frankenphp/crontab /etc/cron.d/cron
RUN touch /var/log/cron.log

# copy sources
COPY --link composer.* ./

RUN set -eux; \
	composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress \
    ;

COPY --link --from=node_base /app/public/build/ public/build

# copy sources
COPY --link . ./
RUN rm -Rf frankenphp/

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
