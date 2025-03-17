# Use ARG to define the PHP version (with default)
ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-cli

LABEL org.opencontainers.image.source="https://github.com/infocyph/LocalDock"
LABEL org.opencontainers.image.description="PHP CLI Supervisor"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

# Set Bash as the default shell
SHELL ["/bin/bash", "-c"]

ARG USERNAME=dockery
ENV USERNAME=${USERNAME}
ARG LINUX_PKG
ARG LINUX_PKG_VERSIONED
ARG PHP_EXT
ARG PHP_EXT_VERSIONED
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/games:$PATH"

# Download PHP extension installer
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN set -eux; \
    apt update && apt upgrade -y && \
    apt install --no-install-recommends -y curl git lolcat boxes supervisor logrotate ${LINUX_PKG//,/ } ${LINUX_PKG_VERSIONED//,/ } && \
    chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions @composer ${PHP_EXT//,/ } ${PHP_EXT_VERSIONED//,/ } && \
    composer self-update --clean-backups && \
    mkdir -p /var/log/supervisor /etc/supervisor/conf.d && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Copy scripts and static supervisor config
COPY scripts/cli-setup.sh /usr/local/bin/cli-setup.sh
COPY scripts/alias-maker.sh /usr/local/bin/alias-maker.sh
COPY scripts/supervisord.conf /etc/supervisor/supervisord.conf
COPY scripts/logrotate-logs /etc/logrotate.d/logrotate-logs
COPY scripts/logrotate-worker.sh /usr/local/bin/logrotate-worker.sh

RUN chmod +x /usr/local/bin/cli-setup.sh /usr/local/bin/alias-maker.sh /usr/local/bin/logrotate-worker.sh

# Add non-root user and sudoer setup
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

# User environment setup (bash theme, aliases, etc.)
USER ${USERNAME}
RUN curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended && \
    sudo /usr/local/bin/alias-maker.sh fpm ${USERNAME} && \
    sudo /usr/local/bin/cli-setup.sh "        Container: PHP-CLI ${PHP_VERSION}" ${USERNAME}

WORKDIR /app

# Supervisor entrypoint
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
