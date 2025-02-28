FROM debian:latest

RUN set -eux; \
    apt update && apt upgrade -y && \
    apt install --no-install-recommends -y curl git lolcat boxes wget ca-certificates fzf autojump bash-completion && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

RUN apt install python3 python3-pip curl git wget net-tools libnss3-tools \
    build-essential python3-dev libcairo2-dev libpango1.0-dev ffmpeg -y && \
    rm -f /usr/lib/python3.*/EXTERNALLY-MANAGED

# Set environment for Composer
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/games:$PATH"
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install mkcert
RUN curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64" && \
    mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert && \
    chmod +x /usr/local/bin/mkcert && \
    mkdir -p /etc/mkcert/localhost

# lazydocker
ENV DIR=/usr/local/bin
RUN curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

# git fame
RUN pip install git-fame && git config --global alias.fame '!python3 -m gitfame' && \
    wget -O /usr/local/bin/owners https://raw.githubusercontent.com/abmmhasan/misc-ref/main/git/owners.sh && \
    chmod +x /usr/local/bin/owners

# Git story
RUN pip install manim gitpython git-story

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
    mkdir -p /home/devuser/.local/share/mkcert && \
    chown -R devuser:devuser /home/devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*
RUN bash -c "mkcert -cert-file \"/etc/mkcert/localhost/fullchain.pem\" -key-file \"/etc/mkcert/localhost/privkey.pem\" \"localhost\""


#ENV COMPOSER_HOME=/home/devuser/.composer
#ENV PATH="$COMPOSER_HOME/vendor/bin:$PATH"
USER devuser
RUN bash -c "curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended && \
    sed -i '/^plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm extract history alias-completion ssh-agent)' /home/devuser/.bashrc && \
    sed -i '/^#plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm extract history alias-completion ssh-agent)' /home/devuser/.bashrc && \
    sed -i 's/^#\\?OSH_THEME=.*/OSH_THEME=\"lambda\"/' /home/devuser/.bashrc && \
    sed -i 's/^#\\?DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE=true/' /home/devuser/.bashrc && \
    echo 'alias cert=\"mkcert -cert-file \"/etc/mkcert/\$1/fullchain.pem\" -key-file \"/etc/mkcert/\$1/privkey.pem\" \"\$1\" \"*.\$1\"\"' >> /home/devuser/.bashrc && \
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

CMD ["tail", "-f", "/dev/null"]
