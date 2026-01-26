ARG NODE_VERSION=current
FROM node:${NODE_VERSION}-alpine

LABEL org.opencontainers.image.source="https://github.com/infocyph/LocalDock"
LABEL org.opencontainers.image.description="NodeJS Alpine"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

ARG USERNAME=dockery
ENV USERNAME=${USERNAME}
ARG UID=1000
ARG GID=1000
ARG LINUX_PKG
ARG LINUX_PKG_VERSIONED
ARG NODE_GLOBAL
ARG NODE_GLOBAL_VERSIONED
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/games:$PATH" \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    NPM_CONFIG_CACHE=/tmp/.npm-cache \
    GIT_CREDENTIAL_STORE=/home/${USERNAME}/.git-credentials

RUN set -eux; apk update && apk add --no-cache bash

# One-shot setup script (mirrors your PHP flow)
ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/node-cli-setup.sh /usr/local/bin/cli-setup.sh
RUN set -eux; bash /usr/local/bin/cli-setup.sh "${USERNAME}" "${NODE_VERSION}"; rm -f /usr/local/bin/cli-setup.sh

USER ${USERNAME}

RUN set -eux; \
    git config --global --add safe.directory "/app/*"; \
    git config --global credential.helper "store --file ${GIT_CREDENTIAL_STORE}"; \
    ( umask 077; : > "${GIT_CREDENTIAL_STORE}" ); \
    if [ -n "${GIT_USER_NAME:-}" ]; then git config --global user.name "${GIT_USER_NAME}"; fi; \
    if [ -n "${GIT_USER_EMAIL:-}" ]; then git config --global user.email "${GIT_USER_EMAIL}"; fi

WORKDIR /app