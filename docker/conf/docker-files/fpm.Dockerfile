ARG PHP_VERSION
FROM php:${PHP_VERSION:-8.3}-fpm

LABEL org.opencontainers.image.source=https://github.com/infocyph/Devtainer
LABEL org.opencontainers.image.description="PHP FPM"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.authors=infocyph,abmmhasan

# Set Bash as default shell
SHELL ["/bin/bash", "-c"]

# System packages (without sudo)
ARG LINUX_PKG
ARG LINUX_PKG_VERSIONED
RUN apt update && apt upgrade -y && \
    if [[ -n "$LINUX_PKG" ]]; then \
        apt install --no-install-recommends -y ${LINUX_PKG//,/ }; \
    fi && \
    if [[ -n "$LINUX_PKG_VERSIONED" ]]; then \
        apt install --no-install-recommends -y ${LINUX_PKG_VERSIONED//,/ }; \
    fi && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# PHP Extensions
ARG PHP_EXT
ARG PHP_EXT_VERSIONED
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions @composer ${PHP_EXT//,/ } ${PHP_EXT_VERSIONED//,/ } && \
    composer self-update --clean-backups && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*
ENV COMPOSER_ALLOW_SUPERUSER=1

# NodeJS
ARG NODE_VERSION
ARG NODE_VERSION_VERSIONED
RUN if [[ -n "$NODE_VERSION_VERSIONED" ]]; then \
        curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION_VERSIONED.x | bash - && \
        apt install --no-install-recommends -y nodejs && \
        npm i -g npm@latest; \
    elif [[ -n "$NODE_VERSION" ]]; then \
        curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION.x | bash - && \
        apt install --no-install-recommends -y nodejs && \
        npm i -g npm@latest; \
    fi && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Add synced system user and install sudo
ARG UID
ARG GID
RUN apt update && \
    useradd -G ${GID:-root} -u ${UID:-1000} -d /home/devuser devuser && \
    apt install sudo -y && \
    mkdir -p /home/devuser/.composer && \
    chown -R devuser:devuser /home/devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

USER devuser
WORKDIR /app
