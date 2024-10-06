FROM debian:latest

RUN apt update && apt upgrade -y && \
    apt install -y --no-install-recommends \
    curl git wget net-tools yq

# mkcert
RUN curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64" && \
    chmod +x mkcert-v*-linux-amd64 && \
    cp mkcert-v*-linux-amd64 /usr/local/bin/mkcert && \
    rm -f mkcert-v*-linux-amd64 && \
    mkdir -p /etc/ssl/custom

# lazydocker
ENV DIR=/usr/local/bin
RUN curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash