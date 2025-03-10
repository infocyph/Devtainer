FROM alpine:latest

RUN set -eux; \
    apk update && apk upgrade && \
    apk add --no-cache \
        curl git lolcat boxes wget ca-certificates fzf autojump bash-completion \
        python3 py3-pip net-tools nss-tools \
        build-base python3-dev cairo-dev pango-dev ffmpeg sudo shadow bash && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    pip install --no-cache-dir git-fame manim gitpython git-story && \
    wget -O /usr/local/bin/owners https://raw.githubusercontent.com/abmmhasan/misc-ref/main/git/owners.sh && \
    chmod +x /usr/local/bin/owners

# Set environment for Composer
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/games:$PATH"
ENV COMPOSER_ALLOW_SUPERUSER=1
ARG USERNAME=dockery

# Install mkcert
RUN curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64" && \
    mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert && \
    chmod +x /usr/local/bin/mkcert && \
    mkdir -p /etc/mkcert

# Install lazydocker
RUN curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

COPY scripts/certify.sh /usr/local/bin/certify
RUN chmod +x /usr/local/bin/certify && /usr/local/bin/certify

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
    apk update && apk add --no-cache sudo && \
    mkdir -p /home/${USERNAME}/.composer/vendor && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

USER ${USERNAME}
RUN bash -c "curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended && \
    sed -i '/^plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm)' /home/${USERNAME}/.bashrc && \
    sed -i '/^#plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm)' /home/${USERNAME}/.bashrc && \
    sed -i 's/^#\\?OSH_THEME=.*/OSH_THEME=\"lambda\"/' /home/${USERNAME}/.bashrc && \
    sed -i 's/^#\\?DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE=true/' /home/${USERNAME}/.bashrc && \
    echo 'alias certify=\"/usr/local/bin/certify\"' >> /home/${USERNAME}/.bashrc && \
    echo 'cat << \"EOF\" | boxes -d parchment -a hcvc | lolcat' >> /home/${USERNAME}/.bashrc && \
    echo ' _                    _ ____             _    ' >> /home/${USERNAME}/.bashrc && \
    echo '| |    ___   ___ __ _| |  _ \\  ___   ___| | __' >> /home/${USERNAME}/.bashrc && \
    echo '| |   / _ \\ / __/ _  | | | | |/ _ \\ / __| |/ /' >> /home/${USERNAME}/.bashrc && \
    echo '| |__| (_) | (_| (_| | | |_| | (_) | (__|   < ' >> /home/${USERNAME}/.bashrc && \
    echo '|_____\\___/ \\___\\__,_|_|____/ \\___/ \\___|_|\\_\\' >> /home/${USERNAME}/.bashrc && \
    echo '----------------------------------------------' >> /home/${USERNAME}/.bashrc && \
    echo '     Container: Tools' >> /home/${USERNAME}/.bashrc && \
    echo 'EOF' >> /home/${USERNAME}/.bashrc"
WORKDIR /app

CMD ["tail", "-f", "/dev/null"]
