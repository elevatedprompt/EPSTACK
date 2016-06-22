#! /bin/bash
##################
# Deploy EPSTACK #
##################
##################################################
# Powered by the cool guys at elevatedprompt.com #
# Get your copy of EPSTACK at epstack.io         #
##################################################
## Install Official Java
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get update
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
sudo apt-get -y install oracle-java8-installer
## Install elasticsearch
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
sudo apt-get update
sudo apt-get -y install elasticsearch
sudo update-rc.d elasticsearch defaults 95 10
sudo /usr/share/elasticsearch/bin/plugin install royrusso/elasticsearch-HQ
sudo sed -i 's/# cluster.name: my-application/ cluster.name: EPSTACK/' /etc/elasticsearch/elasticsearch.yml
sudo sed -i 's/# network.host: 192.168.0.1/ network.host: 127.0.0.1/' /etc/elasticsearch/elasticsearch.yml
sudo service elasticsearch restart
## Install Kibana Service
echo "deb http://packages.elastic.co/kibana/4.4/debian stable main" | sudo tee -a /etc/apt/sources.list.d/kibana-4.4.x.list
sudo apt-get update
sudo apt-get -y install kibana
sudo update-rc.d kibana defaults 96 9
sudo /opt/kibana/bin/kibana plugin -i elastic/timelion
sudo sed -i 's/# server.port: 5601/ server.port: 5601/' /opt/kibana/config/kibana.yml
sudo sed -i 's/# server.host: "0.0.0.0"/ server.host: "127.0.0.1"/' /opt/kibana/config/kibana.yml
sudo sed -i 's/# server.basePath: ""/ server.basePath: "\/kibana4"/' /opt/kibana/config/kibana.yml
sudo sed -i 's/# elasticsearch.url: "http:\/\/localhost:9200"/ elasticsearch.url: "http:\/\/127.0.0.1:9200"/' /opt/kibana/config/kibana.yml
sudo chown -R kibana:kibana /opt/kibana
sudo service kibana stop && sudo service kibana start
## Generate Certs
sudo mkdir -p /etc/pki/tls
sudo mkdir -p /etc/pki/tls/certs
sudo mkdir -p /etc/pki/tls/private
sudo openssl req -subj '/CN=epstack/' -x509 -days 3650 -batch -nodes -newkey rsa:2048 -keyout /etc/pki/tls/private/logstash-forwarder.key -out /etc/pki/tls/certs/logstash-forwarder.crt
## Install Nginx
sudo apt-get install git nginx apache2-utils -y
sudo su -c "cat nginx.conf > /etc/nginx/sites-available/default"
sudo htpasswd -b -c /etc/nginx/conf.d/kibana.htpasswd epadmin epadmin
## Install Logstash
echo 'deb http://packages.elastic.co/logstash/2.2/debian stable main' | sudo tee /etc/apt/sources.list.d/logstash-2.2.x.list
sudo apt-get update
sudo apt-get install logstash
sudo usermod -a -G adm logstash
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
sudo pm2 startup ubuntu
sudo su -c "chmod +x /etc/init.d/pm2-init.sh && update-rc.d pm2-init.sh defaults"
sudo cp /opt/API/configuration.json.sam /opt/API/configuration.json
sudo cp /opt/Notify_API/configuration.json.sam /opt/Notify_API/configuration.json
sudo pm2 restart all
## Ubuntu 16.0.4 uses systemctl
# sudo systemctl enable logstash
# sudo systemctl enable kibana
# sudo systemctl enable elasticsearch
## To Disable IPv6
sudo su -c 'echo "## Disable IPv6 ##" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.conf.all.arp_notify = 1" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf'
sudo sysctl -p
## Install supervisord
## Runs RepDB, ReverseDNS and other jobs
sudo apt-get install python-pip supervisor -y
sudo pip install elasticsearch-curator
##
echo "Please reboot this system"
