#!/usr/bin/with-contenv bashio

# Installation script for WSLink addon


CONFIG_PATH=/data/options.json

HOST_NAME="$(bashio::config 'host_name')"
HOST_IP="$(bashio::config 'host_ip')"
CERT_VALID_FOR="$(bashio::config 'cert_valid_for')"
AUTO_RECREATE_CERT="$(bashio::config 'auto_recreate_cert')"
HA_PORT="$(bashio::config 'ha_port')"


RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
GREEN_YELLOW='\033[1;33m'
NO_COLOR='\033[0m'


# Functions for script

function info() {
    echo -e "${GREEN_COLOR}$1${NO_COLOR}";
        }

function warn() {
    echo -e "${GREEN_YELLOW}$1${NO_COLOR}";
    }

function error() {
    echo -e "${RED_COLOR}$1${NO_COLOR}"
    if [ "{$2:-true}" != "false" ]; then exit 1; fi
}

function check() {
    echo -n "Checking dependencies: '$1' ... "
    if [ -z "$(command -v "$1")" ]; then
        error "not installed" "$2"
        false
    else
        info "OK."
        true
    fi
}

function validate_ip() {

    if [[ "$1" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
        true
    else
        false
    fi
}

function validate_num() {
    if [[ "$1" =~ ^[0-9]+$ ]]; then true; else false; fi
}

function exit_status() {
    # argv 1 - status
    #      2 - called function
    #      3 - error message
    #      4 - success message
    #      5 - exit on error bool

    if [ $1 -ne 0 ]; then
        warn "$2 exited with error: $1"
        error "$3" "$5"
    else
        info "$4"
    fi
}

function create_new_cert()
{
    openssl req -x509 -nodes -newkey rsa:2048 -days "$CERT_VALID_FOR" \
      -keyout /data/ssl/key.pem -out /data/ssl/cert.pem \
      -subj "/CN=$HOST_NAME" \
      -addext "subjectAltName=DNS:$HOST_NAME,IP:$HOST_IP"
    info "New certificate created for hostname $HOST_NAME and IP $HOST_IP"
    info "Generating dhparams (this will take some time)..."
    openssl dhparam -dsaparam -out "/data/ssl/dh.params" 4096 > /dev/null
}

function validate_cert() {
    SUBJECT=$(openssl x509 -in /data/ssl/cert.pem -text -noout | grep -A1 "Subject Alternative Name")
    if ! [[ "$SUBJECT" == *"DNS:$HOST_NAME, IP Address:$HOST_IP"* ]]; then
        if [ "$AUTO_RECREATE_CERT" == "true" ]; then
            info "Certificate validation failed. Recreating certificate."
            create_new_cert
        else
            error "Certificate validation failed" true
        fi
    fi
}

check "openssl" true
check "nginx" true

if ! validate_ip "$HOST_IP" || [ -z "$HOST_IP" ]; then
    error "Invalid IP address" true
fi

# Check if the SSL certificate file exists
if [ ! -f /data/ssl/cert.pem ]; then
    info "No SSL certificate found. Creating new one."
    mkdir -p /data/ssl
    create_new_cert
fi

echo -n "Validating certificate ... "
validate_cert
info "Found valid certificate for hostname $HOST_NAME and IP $HOST_IP"

echo -n "Checking certificate expiration ... "
if openssl x509 -checkend 86400 -noout -in /data/ssl/cert.pem; then
    info "Certificate is valid."
else
    if [ "$AUTO_RECREATE_CERT" == "true" ]; then
        info "Certificate has expired or expiring soon. Recreating certificate."
        create_new_cert
    else
        error "Certificate is about to expire soon or is expired." true
    fi
fi

# Create nginx.conf
info "Creating nginx configuration file..."
sed -e "s/{{ ha_port }}/${HA_PORT}/g" \
    /etc/nginx/nginx.conf.gtpl > /etc/nginx/nginx.conf

# Create add-on status JSON (served by nginx at /status)
info "Creating status.json..."
STARTED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > /data/status.json <<EOF
{
  "ok": true,
  "addon": "wslink_proxy",
  "version": "$(bashio::addon.version 2>/dev/null || echo "unknown")",
  "listen_port": 443,
  "tls": true,
  "started_at": "${STARTED_AT}"
}
EOF

info "Creating status.internal.json ..."
cat > /data/status.internal.json <<EOF
{
  "ok": true,
  "addon": "wslink_proxy",
  "version": "$(bashio::addon.version 2>/dev/null || echo "unknown")",
  "listen": { "port": 443, "tls": true },
  "upstream": { "ha_port": ${HA_PORT} },
  "paths": { "wslink": "/data/upload.php", "wu": "/weatherstation/updateweatherstation.php" }
}
EOF

# Start nginx
bashio::log.info "Running nginx..."
exec nginx -c /etc/nginx/nginx.conf