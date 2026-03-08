ARG BUILD_FROM
FROM $BUILD_FROM

# Copy data for add-on
COPY run.sh /
COPY rootfs /

RUN chmod a+x /run.sh

RUN \
  apk add --no-cache \
  nginx

RUN apk add --no-cache openssl

RUN apk add --no-cache curl jq


CMD [ "/run.sh" ]
