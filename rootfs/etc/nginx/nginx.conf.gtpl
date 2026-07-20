daemon off;
error_log stderr;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    map_hash_bucket_size 128;

    # Docker embedded DNS — lets us re-resolve HA's internal IP without a restart
    resolver 127.0.0.11 ipv6=off valid=10s;
    resolver_timeout 5s;

    map $http_upgrade $connection_upgrade {
        default upgrade;
        ''      close;
    }

    server_tokens off;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    server {
        server_name wslink_proxy;

        ssl_session_timeout 1d;
        ssl_session_cache shared:MozSSL:10m;
        ssl_session_tickets off;

        ssl_certificate /data/ssl/cert.pem;
        ssl_certificate_key /data/ssl/key.pem;
        ssl_dhparam /data/ssl/dh.params;

        listen 443 ssl;
        http2 on;

        proxy_buffering off;

        location / {
            return 400 "Unsupported path.";
        }

        location = /data/upload.php {
            set $ha_upstream homeassistant.local.hass.io;
            proxy_connect_timeout 3s;
            proxy_send_timeout    10s;
            proxy_read_timeout    10s;
            proxy_next_upstream   error timeout;
            proxy_set_header      X-Forwarded-For $remote_addr;
            # $is_args$args is required: when proxy_pass contains a variable,
            # nginx does NOT forward the original query string automatically.
            proxy_pass http://$ha_upstream:{{ ha_port }}/data/upload.php$is_args$args;
        }

        location = /weatherstation/updateweatherstation.php {
            set $ha_upstream homeassistant.local.hass.io;
            proxy_connect_timeout 3s;
            proxy_send_timeout    10s;
            proxy_read_timeout    10s;
            proxy_next_upstream   error timeout;
            proxy_set_header      X-Forwarded-For $remote_addr;
            # $is_args$args is required: when proxy_pass contains a variable,
            # nginx does NOT forward the original query string automatically.
            proxy_pass http://$ha_upstream:{{ ha_port }}/weatherstation/updateweatherstation.php$is_args$args;
        }

        location = /healthz {
            add_header Content-Type text/plain;
            return 200 "ok\n";
        }

        location = /status {
            default_type application/json;
            alias /data/status.json;
            add_header Cache-Control "no-store";
        }

        location = /status/internal {
          allow 127.0.0.1;
          allow 172.30.0.0/16;
          allow 172.16.0.0/12;
          allow 192.168.0.0/16;
          allow 10.0.0.0/8;
          deny all;

          default_type application/json;
          alias /data/status.internal.json;
          add_header Cache-Control "no-store";
      }
    }
}
