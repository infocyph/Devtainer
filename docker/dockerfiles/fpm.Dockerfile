# Use ARG to define the PHP version (with default)
ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-fpm

LABEL org.opencontainers.image.source="https://github.com/infocyph/LocalDock"
LABEL org.opencontainers.image.description="PHP FPM"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

SHELL ["/bin/bash", "-c"]

ARG USERNAME=dockery
ENV USERNAME=${USERNAME}
ARG LINUX_PKG
ARG LINUX_PKG_VERSIONED
ARG PHP_EXT
ARG PHP_EXT_VERSIONED
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN set -eux; \
    apt update && apt upgrade -y && \
    apt install --no-install-recommends -y curl git lolcat boxes ${LINUX_PKG//,/ } ${LINUX_PKG_VERSIONED//,/ } && \
    chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions @composer ${PHP_EXT//,/ } ${PHP_EXT_VERSIONED//,/ } && \
    composer self-update --clean-backups && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*
RUN sed -i 's/^listen = .*/listen = 0.0.0.0:9000/' /usr/local/etc/php-fpm.d/zz-docker.conf

# Set environment
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/games:$PATH"

# Install Node.js and npm globally if requested
ARG NODE_VERSION
ARG NODE_VERSION_VERSIONED
RUN set -eux; \
    if [[ -n "$NODE_VERSION_VERSIONED" || -n "$NODE_VERSION" ]]; then \
        curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION_VERSIONED:-$NODE_VERSION}.x | bash - && \
        apt install --no-install-recommends -y nodejs && \
        npm i -g npm@latest && \
        apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*; \
    fi

COPY scripts/cli-setup.sh /usr/local/bin/cli-setup.sh
COPY scripts/alias-maker.sh /usr/local/bin/alias-maker.sh
RUN chmod +x /usr/local/bin/cli-setup.sh /usr/local/bin/alias-maker.sh

# Add a system user and install sudo
ARG UID=1000
ARG GID=root
RUN set -eux; \
    UID_MIN=$(grep "^UID_MIN" /etc/login.defs | awk '{print $2}') && \
    UID_MAX=$(grep "^UID_MAX" /etc/login.defs | awk '{print $2}') && \
    if [ "$UID" -lt "$UID_MIN" ] || [ "$UID" -gt "$UID_MAX" ]; then \
        echo "UID($UID) is out of range ($UID_MIN-$UID_MAX), setting to default: 1000"; \
        UPDATED_UID=1000; \
    else \
        UPDATED_UID=$UID; \
    fi && \
    useradd -G ${GID} -u ${UPDATED_UID} -d /home/${USERNAME} ${USERNAME} && \
    apt update && apt install --no-install-recommends -y sudo && \
    mkdir -p /home/${USERNAME}/.composer/vendor && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

USER ${USERNAME}
RUN curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended && \
    sudo /usr/local/bin/alias-maker.sh fpm ${USERNAME} && \
    sudo /usr/local/bin/cli-setup.sh "        Container: PHP-FPM ${PHP_VERSION}" ${USERNAME}
WORKDIR /app
