ARG APACHE_VERSION
FROM httpd:${APACHE_VERSION}

LABEL org.opencontainers.image.source="https://github.com/infocyph/LocalDock"
LABEL org.opencontainers.image.description="Apache"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

# Set Apache log directory environment variable
ENV APACHE_LOG_DIR=/var/log/apache2

# Install required Apache modules and utilities
RUN apt update && \
    apt install -y --no-install-recommends apache2-utils libapache2-mod-fcgid && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# Enable required Apache modules
RUN echo "\
LoadModule proxy_module modules/mod_proxy.so\n\
LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so\n\
LoadModule setenvif_module modules/mod_setenvif.so\n\
LoadModule rewrite_module modules/mod_rewrite.so\n\
LoadModule ssl_module modules/mod_ssl.so\n\
LoadModule socache_shmcb_module modules/mod_socache_shmcb.so\n\
LoadModule headers_module modules/mod_headers.so\n\
IncludeOptional conf/extra/*.conf\n\
" >> /usr/local/apache2/conf/httpd.conf

# Set up document root (Mounts will be done via docker-compose)
WORKDIR /app

# Start Apache in the foreground
CMD ["httpd-foreground"]
