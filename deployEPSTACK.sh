#! /bin/bash
##################
# Deploy EPSTACK #
##################
##################################################
# Powered by the cool guys at elevatedprompt.com #
# Get your copy of EPSTACK at epstack.io         #
##################################################
## Disable IPv6
sudo su -c 'echo "## Disable IPv6 ##" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.conf.all.arp_notify = 1" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf'
sudo sysctl -p
## Install Official Java
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get update
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
sudo apt-get -y install oracle-java8-installer
## Install Elasticsearch 5.2
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt-get install apt-transport-https
echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-5.x.list
sudo apt-get update && sudo apt-get install elasticsearch
## Install Logstash 5.2
sudo apt-get install logstash
sudo usermod -a -G adm logstash
## Install Kibana 5.2
sudo apt-get install kibana
## Generate Certs
sudo mkdir -p /etc/pki/tls
sudo mkdir -p /etc/pki/tls/certs
sudo mkdir -p /etc/pki/tls/private
sudo openssl req -subj '/CN=epstack/' -x509 -days 3650 -batch -nodes -newkey rsa:2048 -keyout /etc/pki/tls/private/logstash-forwarder.key -out /etc/pki/tls/certs/logstash-forwarder.crt
## Install Nginx
sudo apt-get install git nginx apache2-utils -y
## NGINX Config ##
sudo cat > /etc/nginx/sites-available/default << EOF
upstream adminpanel {
        server 127.0.0.1:9000;
}

upstream api{
        server 127.0.0.1:3000;
}

upstream kibana {
        server 127.0.0.1:5601;
}

upstream elastic {
        server 127.0.0.1:9200;
}

server {
  listen      *:80;
  return 301 https://\$host\$request_uri;
}

server {
        listen   127.0.0.1:9000;
        location / {
        autoindex on;
        root /var/www/epstack/public_html;
        #index index.html index.htm;
        }
}

server {
        listen *:443 ssl;
        ssl on;
        ssl_certificate         /etc/pki/tls/certs/logstash-forwarder.crt; #/etc/nginx/ssl/server.crt;
        ssl_certificate_key     /etc/pki/tls/private/logstash-forwarder.key; #/etc/nginx/ssl/server.key;

                auth_basic "Restricted Access";
                auth_basic_user_file /etc/nginx/conf.d/kibana.htpasswd;

        ssl_session_cache shared:SSL:20m;
        ssl_session_timeout 10m;
        ssl_prefer_server_ciphers       on;
        ssl_protocols                   TLSv1.1 TLSv1.2;
        ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
        add_header Strict-Transport-Security "max-age=31536000";

        #Setup Logging
        access_log    /var/log/nginx/access.log;
        error_log     /var/log/nginx/error.log;

        location / {
                proxy_pass http://adminpanel;
                proxy_set_header Host \$host;
                proxy_set_header Authorization \$http_authorization;
                proxy_pass_header  Authorization;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location ~ ^/api/(.*)\$ {
                rewrite /api/(.*) /\$1  break;
                proxy_pass http://api;
                proxy_set_header Host \$host;
                proxy_set_header Authorization \$http_authorization;
                proxy_pass_header  Authorization;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location ~ ^/kibana4/(.*)\$ {
                rewrite /kibana4/(.*) /\$1  break;
                proxy_pass http://kibana;
                proxy_set_header Host \$host;
                proxy_set_header Authorization \$http_authorization;
                proxy_pass_header  Authorization;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location ~ ^/elastic/(.*)\$ {
                rewrite /elastic/(.*) /\$1  break;
                proxy_pass http://elastic;
                proxy_set_header Host \$host;
                proxy_set_header Authorization \$http_authorization;
                proxy_pass_header  Authorization;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;
        }
}
EOF
sudo htpasswd -b -c /etc/nginx/conf.d/kibana.htpasswd epadmin epadmin
## Autostart services
sudo update-rc.d elasticsearch defaults 95 10
sudo update-rc.d kibana defaults 96 9
sudo update-rc.d logstash defaults 96 9
## Install PM2 & node.js
sudo apt-get update
sudo apt-get install -y node.js npm
sudo ln -s /usr/bin/nodejs /usr/bin/node
sudo npm install pm2 -g
## Install Main API
cd /opt
sudo git clone https://github.com/elevatedprompt/API
sudo git clone https://github.com/elevatedprompt/Notify_API
cd /opt/API/
sudo npm install
sudo sh installUI.sh
sudo pm2 start index.js --name epstack-API
## Install Notification API
cd /opt/Notify_API
sudo npm install
sudo pm2 start index.js --name epstack-Notify-API
sudo pm2 dump
sudo pm2 startup ubuntu14
sudo su -c "chmod +x /etc/init.d/pm2-init.sh && update-rc.d pm2-init.sh defaults"
sudo cp /opt/API/configuration.json.sam /opt/API/configuration.json
sudo cp /opt/Notify_API/configuration.json.sam /opt/Notify_API/configuration.json
sudo pm2 restart all
## Install supervisord
## Runs RepDB, ReverseDNS and other jobs
sudo apt-get install python-pip supervisor -y
sudo pip install elasticsearch-curator
##
echo "Please reboot this system"
