#syntax=docker/dockerfile:1

ARG NODE_VERSION=24.14.0

# Versions
FROM dunglas/frankenphp:1-php8.5 AS frankenphp_upstream

# Node.js base image
FROM node:${NODE_VERSION}-slim AS node_base

# Base FrankenPHP image
FROM frankenphp_upstream AS frankenphp_base

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

WORKDIR /app

ARG USER=appuser

ENV HOST=localhost
ENV PHP_INI_SCAN_DIR=":$PHP_INI_DIR/app.conf.d"

RUN <<-EOF
    # Use "adduser -D ${USER}" for alpine based distros
    useradd -m -s /bin/bash ${USER}
	# Add additional capability to bind to port 80 and 443
    setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp
	# Give write access to /config, /data and app
    chown -R ${USER}:${USER} /config /data /app
EOF

# persistent deps
# hadolint ignore=DL3008
RUN <<-EOF
	apt-get update
	apt-get install -y --no-install-recommends \
		file \
		git
	install-php-extensions \
		@composer \
		apcu \
		intl \
		opcache \
		zip \
        pcntl
	rm -rf /var/lib/apt/lists/*
EOF

RUN install-php-extensions pdo_pgsql

COPY --link frankenphp/conf.d/10-app.ini $PHP_INI_DIR/app.conf.d/
COPY --link --chmod=755 frankenphp/docker-entrypoint.sh /usr/local/bin/docker-entrypoint

# Install Node.js
COPY --link --from=node_base /usr/local/ /usr/local/
COPY --link --from=node_base /opt/ /opt/

ENTRYPOINT ["docker-entrypoint"]

HEALTHCHECK --start-period=60s CMD php -r 'exit(false === @file_get_contents("http://localhost:2019/metrics", context: stream_context_create(["http" => ["timeout" => 5]])) ? 1 : 0);'
CMD ["sh", "-c", "php artisan octane:frankenphp --host=$HOST --port=443 --https --http-redirect"]

# Dev FrankenPHP image
FROM frankenphp_base AS frankenphp_dev

ENV APP_ENV=dev
ENV XDEBUG_MODE=off

RUN <<-EOF
	mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
	install-php-extensions xdebug
EOF

COPY --link frankenphp/conf.d/20-app.dev.ini $PHP_INI_DIR/conf.d/

USER ${USER}

CMD ["sh", "-c", "php artisan octane:frankenphp --host=$HOST --port=443 --workers=1 --max-requests=1 --watch --poll --https --http-redirect"]

# Builder for the prod FrankenPHP image
FROM frankenphp_base AS frankenphp_prod_builder

ENV APP_ENV=prod
ENV APP_DEBUG=false

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY --link frankenphp/conf.d/20-app.prod.ini $PHP_INI_DIR/app.conf.d/

# prevent the reinstallation of vendors at every changes in the source code
COPY --link composer.* symfony.* package*.json ./
RUN <<-EOF
    composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress
	if [ -f "package-lock.json" ]; then npm ci --no-progress; fi
EOF

# copy sources
COPY --link --exclude=frankenphp/ --exclude=node_modules/ . ./

RUN <<-EOF
	mkdir -p bootstrap/cache storage/app/public storage/app/private/ storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs
	composer dump-autoload --classmap-authoritative --no-dev
	if [ -f "package-lock.json" ]; then
    	npm run build
    	rm -rf node_modules
	fi
    php artisan optimize; sync
EOF

# Collect shared libraries needed by FrankenPHP and PHP extensions
# hadolint ignore=DL3008,SC3054,DL4006
RUN <<-'EOF'
	apt-get update
	apt-get install -y --no-install-recommends libtree
	mkdir -p /tmp/libs
	BINARIES=(frankenphp php file cron)
	for target in $(printf '%s\n' "${BINARIES[@]}" | xargs -I{} which {}) \
		$(find "$(php -r 'echo ini_get("extension_dir");')" -maxdepth 2 -name "*.so"); do
		libtree -pv "$target" 2>/dev/null | grep -oP '(?:── )\K/\S+(?= \[)' | while IFS= read -r lib; do
			[ -f "$lib" ] && cp -n "$lib" /tmp/libs/
		done
	done
	sed -i 's/opcache.preload_user = root/opcache.preload_user = www-data/' "$PHP_INI_DIR/app.conf.d/20-app.prod.ini"
	rm -rf /var/lib/apt/lists/*
EOF

# Prod FrankenPHP image
FROM debian:13-slim AS frankenphp_prod

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ENV HOST=localhost
ENV APP_ENV=production
ENV APP_DEBUG=false
ENV PHP_INI_SCAN_DIR=":/usr/local/etc/php/app.conf.d"

# Install Node.js
COPY --link --from=node_base /usr/local/ /usr/local/
COPY --link --from=node_base /opt/ /opt/

COPY --from=frankenphp_prod_builder /usr/local/bin/frankenphp /usr/local/bin/frankenphp
COPY --from=frankenphp_prod_builder /usr/local/bin/php /usr/local/bin/php
COPY --from=frankenphp_prod_builder /usr/local/bin/docker-php-entrypoint /usr/local/bin/docker-php-entrypoint
COPY --from=frankenphp_prod_builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=frankenphp_prod_builder /tmp/libs /usr/lib

COPY --from=frankenphp_prod_builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d
COPY --from=frankenphp_prod_builder /usr/local/etc/php/php.ini /usr/local/etc/php/php.ini
COPY --from=frankenphp_prod_builder /usr/local/etc/php/app.conf.d /usr/local/etc/php/app.conf.d

# CA certificates for TLS, file/libmagic for Symfony MIME type detection
COPY --from=frankenphp_prod_builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=frankenphp_prod_builder /usr/bin/file /usr/bin/file
COPY --from=frankenphp_prod_builder /usr/lib/file/magic.mgc /usr/lib/file/magic.mgc

# Add crontab file in the cron directory
COPY --link --chmod=0644 frankenphp/crontab /etc/cron.d/cron
RUN touch /var/log/cron.log

ENV XDG_CONFIG_HOME=/config XDG_DATA_HOME=/data

RUN <<-EOF
	mkdir -p /data/caddy /config/caddy
	chown -R www-data:www-data /data /config
	# Remove setuid/setgid bits
	find / -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true
EOF

COPY --from=frankenphp_prod_builder --chown=www-data:www-data /app /app

COPY --link --chmod=755 frankenphp/docker-entrypoint.sh /usr/local/bin/docker-entrypoint

VOLUME /app/storage

USER www-data

WORKDIR /app

ENTRYPOINT ["docker-entrypoint"]

HEALTHCHECK --start-period=60s CMD php -r 'exit(false === @file_get_contents("http://localhost:2019/metrics", context: stream_context_create(["http" => ["timeout" => 5]])) ? 1 : 0);'

CMD ["sh", "-c", "php artisan octane:frankenphp --host=$HOST --port=443 --https --http-redirect"]
