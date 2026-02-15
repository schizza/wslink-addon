daemon off;
error_log stderr;
pid /var/run/nginx.pid;

events {
    worker_connections 6;
}

http {
    map_hash_bucket_size 128;

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
            proxy_pass http://homeassistant.local.hass.io:{{ ha_port }}/data/upload.php;
            # proxy_set_header Host $http_host;
            # proxy_http_version 1.1;
            # proxy_set_header Upgrade $http_upgrade;
            # proxy_set_header Connection $connection_upgrade;
            # proxy_set_header X-Forwarded-Host $http_host;
            # proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            # proxy_set_header X-Forwarded-For $proxy_protocol_addr;
        }

        location = /weatherstation/updateweatherstation.php {
            proxy_pass http://homeassistant.local.hass.io:{{ ha_port }}/weatherstation/updateweatherstation.php;
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
    }
}
