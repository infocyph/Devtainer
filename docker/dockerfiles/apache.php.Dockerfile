# Use ARG to define the PHP version (with default)
ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-apache

LABEL org.opencontainers.image.source="https://github.com/infocyph/LocalDock"
LABEL org.opencontainers.image.description="PHP APACHE"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

# Set Bash as the default shell
SHELL ["/bin/bash", "-c"]

# Install system packages and PHP extensions in one layer to reduce image size
ARG LINUX_PKG
ARG LINUX_PKG_VERSIONED
ARG PHP_EXT
ARG PHP_EXT_VERSIONED
ENV APACHE_LOG_DIR=/var/log/apache2
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN set -eux; \
    apt update && apt upgrade -y && \
    apt install --no-install-recommends -y curl git lolcat boxes ${LINUX_PKG//,/ } ${LINUX_PKG_VERSIONED//,/ } && \
    chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions @composer ${PHP_EXT//,/ } ${PHP_EXT_VERSIONED//,/ } && \
    composer self-update --clean-backups && \
    rm -f /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/default-ssl.conf && \
    a2enmod rewrite ssl socache_shmcb headers && a2ensite * && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Install Node.js and npm globally if requested
ARG NODE_VERSION
ARG NODE_VERSION_VERSIONED
RUN set -eux; \
    if [[ -n "$NODE_VERSION_VERSIONED" || -n "$NODE_VERSION" ]]; then \
        NODE_VERSION_TO_INSTALL="${NODE_VERSION_VERSIONED:-$NODE_VERSION}"; \
        curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION_TO_INSTALL}.x | bash - && \
        apt install --no-install-recommends -y nodejs && \
        npm i -g npm@latest && \
        apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*; \
    fi

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
    useradd -G ${GID} -u ${UPDATED_UID} -d /home/devuser devuser && \
    apt update && apt install --no-install-recommends -y sudo && \
    mkdir -p /home/devuser/.composer/vendor && \
    chown -R devuser:devuser /home/devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

USER devuser
RUN bash -c "curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended && \
    sed -i '/^plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm)' /home/devuser/.bashrc && \
    sed -i '/^#plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm)' /home/devuser/.bashrc && \
    sed -i 's/^#\\?OSH_THEME=.*/OSH_THEME=\"lambda\"/' /home/devuser/.bashrc && \
    sed -i 's/^#\\?DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE=true/' /home/devuser/.bashrc && \
    echo 'cat << \"EOF\" | boxes -d parchment -a hcvc | lolcat' >> /home/devuser/.bashrc && \
    echo ' _                    _ ____             _    ' >> /home/devuser/.bashrc && \
    echo '| |    ___   ___ __ _| |  _ \\  ___   ___| | __' >> /home/devuser/.bashrc && \
    echo '| |   / _ \\ / __/ _  | | | | |/ _ \\ / __| |/ /' >> /home/devuser/.bashrc && \
    echo '| |__| (_) | (_| (_| | | |_| | (_) | (__|   < ' >> /home/devuser/.bashrc && \
    echo '|_____\\___/ \\___\\__,_|_|____/ \\___/ \\___|_|\\_\\' >> /home/devuser/.bashrc && \
    echo '----------------------------------------------' >> /home/devuser/.bashrc && \
    echo '          Brought to you by: Infocyph' >> /home/devuser/.bashrc && \
    echo 'EOF' >> /home/devuser/.bashrc"

WORKDIR /app
