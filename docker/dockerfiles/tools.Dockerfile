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

# Install mkcert
RUN curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64" && \
    mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert && \
    chmod +x /usr/local/bin/mkcert && \
    mkdir -p /etc/mkcert/localhost

# Install lazydocker
RUN curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

# Add system user
ARG UID=1000
ARG GID=root

RUN set -eux; \
    if [ "$UID" -lt 1000 ] || [ "$UID" -gt 60000 ]; then \
        echo "Invalid UID, setting to default: 1000"; \
        UPDATED_UID=1000; \
    else \
        UPDATED_UID=$UID; \
    fi && \
    adduser -u ${UPDATED_UID} -G ${GID} -D -s /bin/bash devuser && \
    mkdir -p /home/devuser/.composer/vendor /home/devuser/.local/share/mkcert && \
    chown -R devuser:devuser /home/devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser

# Generate SSL certificate with mkcert
RUN bash -c "mkcert -cert-file /etc/mkcert/localhost/fullchain.pem -key-file /etc/mkcert/localhost/privkey.pem localhost"

USER devuser
WORKDIR /app

# Install Oh My Bash
RUN bash -c "curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended && \
    sed -i '/^plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm extract history alias-completion ssh-agent)' ~/.bashrc && \
    sed -i '/^#plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm extract history alias-completion ssh-agent)' ~/.bashrc && \
    sed -i 's/^#\\?OSH_THEME=.*/OSH_THEME=\"lambda\"/' ~/.bashrc && \
    sed -i 's/^#\\?DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE=true/' ~/.bashrc && \
    echo 'alias cert=\"mkcert -cert-file \"/etc/mkcert/\$1/fullchain.pem\" -key-file \"/etc/mkcert/\$1/privkey.pem\" \"\$1\" \"*.\$1\"\"' >> ~/.bashrc && \
    echo 'cat << \"EOF\" | boxes -d parchment -a hcvc | lolcat' >> ~/.bashrc && \
    echo ' _                    _ ____             _    ' >> ~/.bashrc && \
    echo '| |    ___   ___ __ _| |  _ \\  ___   ___| | __' >> ~/.bashrc && \
    echo '| |   / _ \\ / __/ _  | | | | |/ _ \\ / __| |/ /' >> ~/.bashrc && \
    echo '| |__| (_) | (_| (_| | | |_| | (_) | (__|   < ' >> ~/.bashrc && \
    echo '|_____\\___/ \\___\\__,_|_|____/ \\___/ \\___|_|\\_\\' >> ~/.bashrc && \
    echo '----------------------------------------------' >> ~/.bashrc && \
    echo '          Brought to you by: Infocyph' >> ~/.bashrc && \
    echo 'EOF' >> ~/.bashrc"

CMD ["tail", "-f", "/dev/null"]
