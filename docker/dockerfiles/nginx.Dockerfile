ARG NGINX_VERSION
FROM nginx:${NGINX_VERSION:-latest}

LABEL org.opencontainers.image.source="https://github.com/infocyph/LocalDock"
LABEL org.opencontainers.image.description="NGINX with updated FastCGI params"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

# Copy the update script into the container
COPY scripts/fcgi-params.sh /usr/local/bin/fcgi_params.sh
COPY scripts/proxy-params.sh /usr/local/bin/proxy_params.sh

# Set execute permissions for the script
RUN mkdir -p /etc/share/rootCA /etc/mkcert && \
    chmod +x /usr/local/bin/fcgi_params.sh /usr/local/bin/proxy_params.sh && \
    /usr/local/bin/fcgi_params.sh && /usr/local/bin/proxy_params.sh

# Expose ports
EXPOSE 80 443

# Command to run NGINX in the foreground
CMD ["nginx", "-g", "daemon off;"]
