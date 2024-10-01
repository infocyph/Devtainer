FROM certbot/certbot:latest
RUN apt-get update && apt-get install -y --no-install-recommends docker-cli
COPY scripts/certbot-renew /usr/local/bin/certbot-renew
RUN chmod +x /usr/local/bin/certbot-renew
CMD ["/usr/local/bin/certbot-renew"]
