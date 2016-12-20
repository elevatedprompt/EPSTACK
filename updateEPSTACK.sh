######### Update EPSTACK #########
#! /bin/bash
sudo pm2 stop all
cd /opt/API/
sudo git pull
cd /opt/Notify_API/
sudo git pull
cd /var/www/epstack/public_html/
sudo git pull
sudo pm2 start all
cd ~/
##################################
