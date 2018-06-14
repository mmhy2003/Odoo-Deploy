#!/bin/bash
###################################################################
# Script for installing nginx for odoo on Ubuntu 16.04
# Author: Mohamed Hammad
# -----------------------------------------------------------------
# Make a new file:
# sudo nano 03-nginx-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x 03-nginx-install.sh
# Execute the script to install nginx:
# sudo ./03-nginx-install.sh
###################################################################

OE_DOMAIN="odoo.com *.odoo.com"
OE_HOST="127.0.0.1"
OE_PORT="8069"
NGINX_CONFIG="odoo"
NGINX_CONFIG_PATH="/etc/nginx/sites-available/${NGINX_CONFIG}"

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo apt update
sudo apt dist-upgrade -yV

#--------------------------------------------------
# Install certbot
#--------------------------------------------------
echo -e "\n---- Install certbot ----"
sudo apt install software-properties-common
sudo add-apt-repository ppa:certbot/certbot -y
sudo apt update
sudo apt install python-certbot-nginx -yV

#--------------------------------------------------
# Create configuration file
#--------------------------------------------------
echo -e "\n---- Create configuration file ----"
cat <<EOF > ~/${NGINX_CONFIG}
#odoo server
upstream odoo {
        server $OE_HOST:$OE_PORT weight=1 fail_timeout=0;
        #server <SECOND-SERVER>:$OE_PORT weight=1 fail_timeout=0;
}
upstream odoochat {
        server $OE_HOST:8072 weight=1 fail_timeout=0;
        #server <SECOND-SERVER>:8072 weight=1 fail_timeout=0;
}

# http -> https
#server {
#        listen 80;
#        listen [::]:80 ipv6only=on;
#        server_name $OE_DOMAIN;
#        add_header Strict-Transport-Security max-age=2592000;
#        rewrite ^/.*$ https://\$host\$request_uri? permanent;
#}

server {
        #listen 443;
        #listen [::]:443 ipv6only=on;
        listen 80;
        listen [::]:80 ipv6only=on;
        server_name $OE_DOMAIN;
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;
        keepalive_timeout 60;

        # Add Headers for odoo proxy mode
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;

        # SSL parameters
        #ssl on;
        #ssl_certificate /etc/letsencrypt/live/<DOMAIN>/fullchain.pem;
        #ssl_certificate_key /etc/letsencrypt/live/<DOMAIN>/privkey.pem;
        #ssl_session_timeout 30m;
        #ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        #ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
        #ssl_prefer_server_ciphers on;

        # log
        access_log /var/log/nginx/odoo.access.log;
        error_log /var/log/nginx/odoo.error.log;

        # Redirect requests to odoo backend server
        location / {
                proxy_redirect off;
                proxy_pass http://odoo;
        }

        location /longpolling {
                proxy_pass http://odoochat;
        }

        # cache some static data in memory for 60mins.
        # under heavy load this should relieve stress on the OpenERP web interface a bit.
        location ~* /[0-9a-zA-Z_]*/static/ {
                proxy_cache_valid 200 60m;
                proxy_buffering on;
                expires 864000;
                proxy_pass http://odoo;
        }

        # common gzip
        gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript;
        gzip on;
}
EOF

sudo mv ~/${NGINX_CONFIG} ${NGINX_CONFIG_PATH}
sudo chmod 755 ${NGINX_CONFIG_PATH}
sudo chown root: ${NGINX_CONFIG_PATH}

#--------------------------------------------------
# Enable website
#--------------------------------------------------
echo -e "\n---- Enable website ----"
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s ${NGINX_CONFIG_PATH} /etc/nginx/sites-enabled/.

#--------------------------------------------------
# Restart nginx service
#--------------------------------------------------
echo -e "\n---- Restart nginx service ----"
sudo service nginx restart
