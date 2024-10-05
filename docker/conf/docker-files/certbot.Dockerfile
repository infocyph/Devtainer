FROM certbot/certbot:latest
RUN apt update && apt install -y --no-install-recommends docker-cli
COPY scripts/certbot-renew /usr/local/bin/certbot-renew
COPY scripts/certbot-hook /usr/local/bin/reload-services
RUN chmod +x /usr/local/bin/certbot-renew /usr/local/bin/reload-services
CMD ["/usr/local/bin/certbot-renew"]
