FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/infocyph/LocalDock"
LABEL org.opencontainers.image.description="PHP APACHE NODE"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

# Install Supervisor and Docker CLI
RUN apk update && apk add curl supervisor docker-cli logrotate

ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/confs/supervisord.conf /etc/supervisor/supervisord.conf
ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/logrotate-worker.sh /usr/local/bin/logrotate-worker.sh
RUN chmod +x /usr/local/bin/logrotate-worker.sh
COPY scripts/logrotate-logs /etc/logrotate.d/logrotate-logs

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]

