# Use ARG to define the PHP version (with default)
ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-fpm

LABEL org.opencontainers.image.source="https://github.com/infocyph/Devtainer"
LABEL org.opencontainers.image.description="PHP FPM"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

# Set Bash as the default shell
SHELL ["/bin/bash", "-c"]

# Install system packages and PHP extensions in one layer to reduce image size
ARG LINUX_PKG
ARG LINUX_PKG_VERSIONED
ARG PHP_EXT
ARG PHP_EXT_VERSIONED
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN set -eux; \
    apt update && apt upgrade -y && \
    apt install --no-install-recommends -y curl ${LINUX_PKG//,/ } ${LINUX_PKG_VERSIONED//,/ } && \
    chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions @composer ${PHP_EXT//,/ } ${PHP_EXT_VERSIONED//,/ } && \
    composer self-update --clean-backups && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Set environment for Composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install Node.js and npm globally if requested
ARG NODE_VERSION
ARG NODE_VERSION_VERSIONED

RUN set -eux; \
    if [[ -n "$NODE_VERSION_VERSIONED" || -n "$NODE_VERSION" ]]; then \
        NODE_VERSION_TO_INSTALL="${NODE_VERSION_VERSIONED:-$NODE_VERSION}"; \
        curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION_TO_INSTALL}.x | bash - && \
        apt install --no-install-recommends -y nodejs && \
        npm i -g npm@latest; \
    fi && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Add a system user and install sudo
ARG UID=1000
ARG GID=root

RUN set -eux; \
    apt update && \
    useradd -G ${GID} -u ${UID} -d /home/devuser devuser && \
    apt install --no-install-recommends -y sudo && \
    mkdir -p /home/devuser/.composer && \
    chown -R devuser:devuser /home/devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Switch to the non-root user and set the working directory
USER devuser
WORKDIR /app
