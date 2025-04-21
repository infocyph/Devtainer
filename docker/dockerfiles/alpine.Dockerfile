ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-fpm-alpine

LABEL org.opencontainers.image.source="https://github.com/infocyph/LocalDock"
LABEL org.opencontainers.image.description="PHP FPM Alpine"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="infocyph,abmmhasan"

ARG USERNAME=dockery
ENV USERNAME=${USERNAME}
ARG LINUX_PKG
ARG LINUX_PKG_VERSIONED
ARG PHP_EXT
ARG PHP_EXT_VERSIONED
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/games:$PATH"

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN set -eux; \
    apk update && \
    apk add --no-cache curl git figlet bash shadow ${LINUX_PKG//,/ } ${LINUX_PKG_VERSIONED//,/ } && \
    chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions @composer ${PHP_EXT//,/ } ${PHP_EXT_VERSIONED//,/ } && \
    composer self-update --clean-backups && \
    sed -i 's/^listen = .*/listen = 0.0.0.0:9000/' /usr/local/etc/php-fpm.d/zz-docker.conf

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/cli-setup.sh /usr/local/bin/cli-setup.sh
ADD https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/banner.sh /usr/local/bin/show-banner
ADD https://raw.githubusercontent.com/infocyph/Toolset/main/Git/gitx /usr/local/bin/gitx
ADD https://raw.githubusercontent.com/infocyph/Toolset/main/ChromaCat/chromacat /usr/local/bin/chromacat

# Add a system user and setup sudo
ARG UID=1000
ARG GID=1000
RUN set -eux; \
    UPDATED_UID=${UID:-1000}; \
    UPDATED_GID=${GID:-1000}; \
    # Create group if doesn't exist
    if ! getent group "${UPDATED_GID}" >/dev/null; then \
        addgroup -g "${UPDATED_GID}" "${USERNAME}"; \
    fi; \
    # Create user with specified UID/GID
    adduser -D -u "${UPDATED_UID}" -G "$(getent group "${UPDATED_GID}" | cut -d: -f1)" \
        -h "/home/${USERNAME}" -s /bin/sh "${USERNAME}"; \
    apk update && apk add --no-cache sudo; \
    # Set up composer directory
    mkdir -p "/home/${USERNAME}/.composer/vendor"; \
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"; \
    # Setup sudoers
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}"; \
    chmod 0440 "/etc/sudoers.d/${USERNAME}"; \
    rm -rf /var/cache/apk/* /tmp/* /var/tmp/*


RUN chown ${USERNAME}:${USERNAME} /usr/local/bin/cli-setup.sh /usr/local/bin/show-banner /usr/local/bin/gitx /usr/local/bin/chromacat && \
    chmod +x /usr/local/bin/cli-setup.sh /usr/local/bin/show-banner /usr/local/bin/gitx /usr/local/bin/chromacat

USER ${USERNAME}
RUN curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended && \
    sudo /usr/local/bin/cli-setup.sh ${USERNAME} && \
    echo 'show-banner "LocalDock" "PHP ${PHP_VERSION}"' >> ~/.bashrc

WORKDIR /app
