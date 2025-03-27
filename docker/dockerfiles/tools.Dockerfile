FROM debian:stable-slim

LABEL org.opencontainers.image.source="https://github.com/infocyph/LocalDock"
LABEL org.opencontainers.image.description="Tools"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

# Set environment for Composer
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/games:$PATH"
ENV CAROOT=/etc/share/rootCA
ARG USERNAME=dockery
ENV USERNAME=${USERNAME}

RUN set -eux; \
    apt update && apt upgrade -y && \
    apt install --no-install-recommends -y curl git lolcat boxes wget ca-certificates figlet locales fzf autojump bash-completion \
    net-tools libnss3-tools iputils-ping nano btop tmux ncdu jq tree nmap && \
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen en_US.UTF-8 && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Install mkcert
RUN curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64" && \
    mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert && \
    chmod +x /usr/local/bin/mkcert && \
    mkdir -p /etc/mkcert

# Install lazydocker
ENV DIR=/usr/local/bin
RUN curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/certify.sh /usr/local/bin/certify
ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/cli-setup.sh /usr/local/bin/cli-setup.sh
ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/banner.sh /usr/local/bin/show-banner
ADD https://raw.githubusercontent.com/infocyph/Toolset/main/Git/gitx /usr/local/bin/gitx

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
    apt update && apt install --no-install-recommends -y sudo && \
    useradd -G ${GID} -u ${UPDATED_UID} -d /home/${USERNAME} ${USERNAME} && \
    mkdir -p /home/${USERNAME}/.composer/vendor \
             /etc/share/rootCA \
             /etc/share/vhosts/apache \
             /etc/share/vhosts/nginx && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

USER ${USERNAME}
RUN sudo chown ${USERNAME}:${USERNAME} /usr/local/bin/cli-setup.sh /usr/local/bin/show-banner /usr/local/bin/gitx  /usr/local/bin/certify && \
    sudo chmod +x /usr/local/bin/cli-setup.sh /usr/local/bin/show-banner /usr/local/bin/gitx  /usr/local/bin/certify && \
    curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended && \
    sudo /usr/local/bin/cli-setup.sh ${USERNAME} && \
    echo 'show-banner "LocalDock" "Container: Tools"' >> ~/.bashrc

WORKDIR /app
CMD ["/bin/bash", "-c", "/usr/local/bin/certify && tail -f /dev/null"]
