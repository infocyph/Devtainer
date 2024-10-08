FROM ubuntu:latest

# Update and install base packages in one RUN step for optimization
RUN apt update && apt upgrade -y && \
    apt install -y --no-install-recommends \
    git wget curl ca-certificates sudo && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Install yq
RUN curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

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
    mkdir -p /home/devuser/.composer && \
    chown -R devuser:devuser /home/devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Switch to the non-root user and set the working directory
USER devuser
WORKDIR /app

# Default command to keep the container running
CMD ["tail", "-f", "/dev/null"]
