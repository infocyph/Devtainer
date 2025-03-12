FROM debian:stable-slim

RUN set -eux; \
    apt update && apt upgrade -y && \
    apt install --no-install-recommends -y curl git lolcat boxes wget ca-certificates fzf autojump bash-completion \
    python3 python3-pip curl git wget net-tools libnss3-tools \
    build-essential python3-dev libcairo2-dev libpango1.0-dev ffmpeg -y && \
    rm -f /usr/lib/python3.*/EXTERNALLY-MANAGED && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Set environment for Composer
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/games:$PATH"
ENV CAROOT=/etc/share/rootCA
ARG USERNAME=dockery

# Install mkcert
RUN curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64" && \
    mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert && \
    chmod +x /usr/local/bin/mkcert && \
    mkdir -p /etc/mkcert

# lazydocker
ENV DIR=/usr/local/bin
RUN curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

# git fame
RUN pip install git-fame && git config --global alias.fame '!python3 -m gitfame' && \
    wget -O /usr/local/bin/owners https://raw.githubusercontent.com/abmmhasan/misc-ref/main/git/owners.sh && \
    chmod +x /usr/local/bin/owners

# Git story
RUN pip install manim gitpython git-story

COPY scripts/certify.sh /usr/local/bin/certify
COPY scripts/cli-setup.sh /usr/local/bin/cli-setup.sh
COPY scripts/alias-maker.sh /usr/local/bin/alias-maker.sh
RUN chmod +x /usr/local/bin/certify /usr/local/bin/cli-setup.sh /usr/local/bin/alias-maker.sh

# Add a system user and install sudo
ARG UID=1000
ARG GID=1000

RUN set -eux; \
    UID_MIN=$(grep "^UID_MIN" /etc/login.defs | awk '{print $2}') && \
    UID_MAX=$(grep "^UID_MAX" /etc/login.defs | awk '{print $2}') && \
    if [ "$UID" -lt "$UID_MIN" ] || [ "$UID" -gt "$UID_MAX" ]; then \
        echo "UID is out of range ($UID_MIN-$UID_MAX), setting to default: 1000"; \
        UPDATED_UID=1000; \
    else \
        UPDATED_UID=$UID; \
    fi && \
    useradd -G ${GID} -u ${UPDATED_UID} -d /home/${USERNAME} ${USERNAME} && \
    apt update && apt install --no-install-recommends -y sudo && \
    mkdir -p /home/${USERNAME}/.composer/vendor \
    /etc/share/rootCA \
    /etc/share/vhosts/apache \
    /etc/share/vhosts/nginx && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

USER ${USERNAME}
RUN /usr/local/bin/certify && sudo /usr/local/bin/alias-maker.sh tools && sudo /usr/local/bin/cli-setup.sh "             Container: Tools"
WORKDIR /app

CMD ["/bin/bash", "-c", "/usr/local/bin/certify && tail -f /dev/null"]
