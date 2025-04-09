FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/infocyph/LocalDock"
LABEL org.opencontainers.image.description="RUNNER (SUPERVISOR)"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

# Install Supervisor and Docker CLI
RUN apk update && apk add curl supervisor docker-cli logrotate bash && mkdir -p /var/log/supervisor /etc/supervisor/conf.d
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/games:$PATH"
ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/confs/supervisord.conf /etc/supervisor/supervisord.conf
ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/logrotate-worker.sh /usr/local/bin/logrotate-worker.sh
ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/dexec-php.sh /usr/local/bin/dexec
COPY scripts/logrotate-logs /etc/logrotate.d/logrotate-logs
RUN chmod +x /usr/local/bin/logrotate-worker.sh /usr/local/bin/dexec && \
    chmod 644 /etc/supervisor/supervisord.conf && chmod 775 /var/log/supervisor

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]

