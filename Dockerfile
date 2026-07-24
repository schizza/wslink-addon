ARG BUILD_ARCH=amd64
FROM ghcr.io/home-assistant/${BUILD_ARCH}-base:3.21

# Copy data for add-on
COPY run.sh /
COPY rootfs /

RUN chmod a+x /run.sh

RUN \
  apk add --no-cache \
    curl \
    jq \
    nginx \
    openssl


CMD [ "/run.sh" ]
