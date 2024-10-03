FROM certbot/certbot:latest
RUN apt update && apt install -y --no-install-recommends docker-cli
COPY scripts/certbot-renew /usr/local/bin/certbot-renew
RUN chmod +x /usr/local/bin/certbot-renew
CMD ["/usr/local/bin/certbot-renew"]
