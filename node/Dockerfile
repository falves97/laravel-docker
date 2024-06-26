FROM node:20-alpine as node_base

RUN set -eux; \
    apk add --no-cache openssl \
    curl \
    ;

EXPOSE 3000

WORKDIR app/

COPY --link --chmod=755 node/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
ENTRYPOINT ["docker-entrypoint"]

FROM node_base as node_dev

ENV NODE_ENV=development

CMD ["yarn", "dev", "--host", "--port", "3000"]