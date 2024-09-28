ARG PHP_VERSION
FROM php:${PHP_VERSION:-8.3}-cli

LABEL org.opencontainers.image.source=https://github.com/infocyph/Devtainer
LABEL org.opencontainers.image.description="PHP CLI with Cron and Supervisor"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.authors=infocyph,abmmhasan

# Set Bash as default shell
SHELL ["/bin/bash", "-c"]

# System packages (without sudo)
ARG LINUX_PKG
ARG LINUX_PKG_VERSIONED
RUN apt update && apt upgrade -y && \
    apt install --no-install-recommends -y cron supervisor ${LINUX_PKG//,/ } ${LINUX_PKG_VERSIONED//,/ } && \
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

# Add synced system user and install sudo after user creation
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

# Configure supervisord
RUN mkdir -p /etc/supervisor/conf.d

# Configure cron
RUN touch /var/log/cron.log

USER devuser
WORKDIR /app

# Run supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
