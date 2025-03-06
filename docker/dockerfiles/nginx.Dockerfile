ARG NGINX_VERSION
FROM nginx:${NGINX_VERSION}

LABEL org.opencontainers.image.source="https://github.com/infocyph/LocalDock"
LABEL org.opencontainers.image.description="NGINX with updated FastCGI params"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

# Copy the update script into the container
COPY scripts/fcgi-proxy-params.sh /usr/local/bin/update_params.sh

# Set execute permissions for the script
RUN chmod +x /usr/local/bin/update_params.sh && \
    /usr/local/bin/update_params.sh && \
    rm -f /usr/local/bin/update_params.sh

# Expose ports
EXPOSE 80 443

# Command to run NGINX in the foreground
CMD ["nginx", "-g", "daemon off;"]
