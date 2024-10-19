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

# Add a system user and install sudo
ARG UID=1000
ARG GID=root

RUN set -eux; \
    UID_MIN=$(grep "^UID_MIN" /etc/login.defs | awk '{print $2}') && \
    UID_MAX=$(grep "^UID_MAX" /etc/login.defs | awk '{print $2}') && \
    if [ "$UID" -lt "$UID_MIN" ] || [ "$UID" -gt "$UID_MAX" ]; then \
        echo "UID is out of range ($UID_MIN-$UID_MAX), setting to default: 1000"; \
        UPDATED_UID=1000; \
    else \
        UPDATED_UID=$UID; \
    fi && \
    useradd -G ${GID} -u ${UPDATED_UID} -d /home/devuser devuser && \
    apt update && apt install --no-install-recommends -y sudo && \
    mkdir -p /home/devuser/.composer/vendor && \
    chown -R devuser:devuser /home/devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Configure supervisord and cron
RUN mkdir -p /etc/supervisor/conf.d && \
    touch /var/log/cron.log

# Switch to non-root user
USER devuser
RUN bash -c "curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended && \
    sed -i '/^plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm extract history alias-completion ssh-agent)' /home/devuser/.bashrc && \
    sed -i '/^#plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm extract history alias-completion ssh-agent)' /home/devuser/.bashrc && \
    sed -i 's/^#\\?OSH_THEME=.*/OSH_THEME=\"lambda\"/' /home/devuser/.bashrc"
WORKDIR /app

# Default command: start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
