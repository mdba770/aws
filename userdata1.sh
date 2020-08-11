#!/bin/bash

### Update Server

yum -y update 

### Add repo

yum -y  install epel-release

## Install  nginx 

yum -y install nginx awscli

### Delete default nginx index

rm -f  /usr/share/nginx/html/index.html

#### Copy files from  s3 

aws s3 cp  s3://langosh/blue/index.html /usr/share/nginx/html/

ln -s /usr/share/nginx/html /usr/share/nginx/html/blue

## Start & Enable Nginx 

systemctl enable nginx 
systemctl start nginx 

firewall-cmd --zone=public --add-port=80/tcp --permanent

firewall-cmd --reload



######################

echo "End of script"


