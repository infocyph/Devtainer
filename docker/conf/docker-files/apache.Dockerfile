ARG APACHE_VERSION
FROM httpd:${APACHE_VERSION}

LABEL org.opencontainers.image.source=https://github.com/infocyph/Devtainer
LABEL org.opencontainers.image.description="Apache"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.authors=infocyph,abmmhasan

# Set Apache log directory environment variable
ENV APACHE_LOG_DIR=/var/log/apache2

# Install required Apache modules and clean up
RUN apt update && apt install -y --no-install-recommends libapache2-mod-fcgid && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Remove default Apache site configurations
RUN rm -f /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/default-ssl.conf

# Enable necessary Apache modules
RUN a2enmod proxy_fcgi setenvif rewrite ssl socache_shmcb headers && a2ensite *

# Include virtual hosts configuration in the main Apache configuration
RUN echo "IncludeOptional conf/extra/httpd-vhosts.conf" >> /usr/local/apache2/conf/httpd.conf

# Set up document root (Mounts will be done via docker-compose)
WORKDIR /var/www/html

# Start Apache in the foreground
CMD ["httpd-foreground"]
