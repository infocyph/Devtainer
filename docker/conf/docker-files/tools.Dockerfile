FROM debian:latest

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN set -eux; \
    apt update && apt upgrade -y && \
    apt install --no-install-recommends -y curl git wget ca-certificates php-cli && \
    chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions @composer yaml zip && \
    composer self-update --clean-backups && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Set environment for Composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install mkcert
RUN curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64" && \
    chmod +x mkcert-v*-linux-amd64 && \
    cp mkcert-v*-linux-amd64 /usr/local/bin/mkcert && \
    rm -f mkcert-v*-linux-amd64 && \
    mkdir -p /etc/ssl/custom

# lazydocker
ENV DIR=/usr/local/bin
RUN curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

# Add a system user and install sudo
ARG UID=1000
ARG GID=root
RUN set -eux; \
    useradd -G ${GID} -u ${UID} -d /home/devuser devuser && \
    mkdir -p /home/devuser/.composer/vendor && \
    chown -R devuser:devuser /home/devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*
ENV COMPOSER_HOME=/home/devuser/.composer
ENV PATH="$COMPOSER_HOME/vendor/bin:$PATH"
# Switch to the non-root user and set the working directory
USER devuser
WORKDIR /mount

# Install PHP dependencies (Symfony Dotenv, Yaml, Laravel Prompts)
RUN composer global require symfony/dotenv symfony/yaml laravel/prompts

# Default command to keep the container running
CMD ["tail", "-f", "/dev/null"]
