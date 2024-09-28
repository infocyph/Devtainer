ARG PHP_VERSION
FROM php:${PHP_VERSION:-8.3}-fpm

LABEL org.opencontainers.image.source=https://github.com/infocyph/Devtainer
LABEL org.opencontainers.image.description="PHP FPM"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.authors=infocyph,abmmhasan

# System packages
ARG LINUX_PACKAGES
RUN apt update && apt upgrade -y
RUN ["/bin/bash", "-c", "if [[ -n \"$LINUX_PACKAGES\" ]]; then apt install ${LINUX_PACKAGES//,/ } -y; fi"]

# PHP Extensions
ARG PHP_EXTENSIONS
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions
RUN ["/bin/bash", "-c", "install-php-extensions @composer ${PHP_EXTENSIONS//,/ } && composer self-update --clean-backups"]
ENV COMPOSER_ALLOW_SUPERUSER=1

# NodeJS
ARG NODE_VERSION
RUN ["/bin/bash", "-c", "if [[ -n \"$NODE_VERSION\" ]]; then curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION.x | bash - && apt install nodejs -y && npm i -g npm@latest; fi"]

# Sudo
RUN apt update &&  \
    apt install sudo -y &&  \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Add synced system user
ARG UID
ARG GID
RUN useradd -G ${GID:-root} -u ${UID:-1000} -d /home/devuser devuser && \
    mkdir -p /home/devuser/.composer && \
    chown -R devuser:devuser /home/devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
USER devuser

WORKDIR /app