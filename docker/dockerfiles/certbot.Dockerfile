FROM certbot/certbot:latest

# Install docker-cli and clean up package lists
RUN apt update && \
    apt install -y --no-install-recommends docker-cli && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Copy scripts and make them executable
ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/certbot-renew.sh /usr/local/bin/certbot-renew
ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/certbot-hook.sh /usr/local/bin/reload-services
RUN chmod +x /usr/local/bin/certbot-renew /usr/local/bin/reload-services

# Set default command
CMD ["/usr/local/bin/certbot-renew"]
