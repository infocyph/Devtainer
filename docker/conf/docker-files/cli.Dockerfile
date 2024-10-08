# Use ARG to define the PHP version (with default)
ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-cli

LABEL org.opencontainers.image.source="https://github.com/infocyph/Devtainer"
LABEL org.opencontainers.image.description="PHP CLI with Cron and Supervisor"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

# Set Bash as the default shell
SHELL ["/bin/bash", "-c"]

# Install system packages, PHP extensions, and necessary tools
ARG LINUX_PKG
ARG LINUX_PKG_VERSIONED
ARG PHP_EXT
ARG PHP_EXT_VERSIONED
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN set -eux; \
    apt update && \
    apt install --no-install-recommends -y cron supervisor ${LINUX_PKG//,/ } ${LINUX_PKG_VERSIONED//,/ } && \
    chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions @composer ${PHP_EXT//,/ } ${PHP_EXT_VERSIONED//,/ } && \
    composer self-update --clean-backups && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Set environment for Composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Add synced system user
ARG UID=1000
ARG GID=root
RUN set -eux; \
    useradd -G ${GID} -u ${UID} -d /home/devuser devuser && \
    apt install --no-install-recommends -y sudo && \
    mkdir -p /home/devuser/.composer && \
    chown -R devuser:devuser /home/devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Configure supervisord and cron
RUN mkdir -p /etc/supervisor/conf.d && \
    touch /var/log/cron.log

# Switch to non-root user
USER devuser
WORKDIR /app

# Default command: start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
