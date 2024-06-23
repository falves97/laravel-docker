FROM node:20-alpine as node_base

USER node

EXPOSE 3000

WORKDIR app/

COPY --link --chmod=755 ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint

FROM node_base as node_dev

ENV NODE_ENV=development
ENTRYPOINT ["docker-entrypoint"]

CMD ["yarn", "dev", "--host", "--port", "3000"]

HEALTHCHECK CMD curl --fail http://localhost:3000 || exit 1

FROM node_base as node_prod

ENV NODE_ENV=production
ENTRYPOINT ["docker-entrypoint"]

CMD ["yarn", "build"]