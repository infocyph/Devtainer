FROM debian:latest

RUN set -eux; \
    apt update && apt upgrade -y && \
    apt install --no-install-recommends -y curl git wget ca-certificates && \
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


#ENV COMPOSER_HOME=/home/devuser/.composer
#ENV PATH="$COMPOSER_HOME/vendor/bin:$PATH"
USER devuser
RUN bash -c "curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended && \
    sed -i '/^plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm extract history alias-completion ssh-agent)' /home/devuser/.bashrc && \
    sed -i '/^#plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm extract history alias-completion ssh-agent)' /home/devuser/.bashrc && \
    sed -i 's/^#\\?OSH_THEME=.*/OSH_THEME=\"lambda\"/' /home/devuser/.bashrc"
WORKDIR /app

# Default command to keep the container running
CMD ["tail", "-f", "/dev/null"]
