#!/bin/bash

set -eux

# Generate key
ssh-keygen -t rsa -b 2048 -C "${USER}@$(hostname -I | awk '{ print $1 }')"
cp /root/.ssh/id_rsa.pub /ad-hub.net/docker-service/ext-id_rsa.pub

# Generate Diffie-Hellman keys
openssl dhparam -out /ad-hub.net/docker-service/config/nginx/dhparam.pem 2048

apt update
apt install -y jq make memcached nfs-kernel-server software-properties-common

# Install Certbot
add-apt-repository universe
add-apt-repository -y ppa:certbot/certbot
apt-get update
apt-get install -y certbot

# Install Nodejs
curl -sL https://deb.nodesource.com/setup_8.x | bash -
apt-get install -y nodejs

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Docker
apt-get remove docker docker-engine docker.io containerd runc
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Generate media folders
mkdir -p \
 /export/ad-hub.net \
 /export/letsencrypt \
 /ad-hub.net/apps \
 /ad-hub.net/media \
 /ad-hub.net/media/acho_beta_file_queue \
 /ad-hub.net/media/acho_beta_locks \
 /ad-hub.net/media/acho_file_queue \
 /ad-hub.net/media/acho_job/downloadChannelFriendCSVAsync \
 /ad-hub.net/media/acho_locks \
 /ad-hub.net/media/line_carousel_images \
 /ad-hub.net/media/line_channel_pictures \
 /ad-hub.net/media/line_chat_images \
 /ad-hub.net/media/line_coupon_images \
 /ad-hub.net/media/line_crop_images \
 /ad-hub.net/media/line_imagemap \
 /ad-hub.net/media/line_images \
 /ad-hub.net/media/line_message_image \
 /ad-hub.net/media/line_rich_menu_images \
 /ad-hub.net/media/line_survey_images \
 /ad-hub.net/media/line_tools \
 /ad-hub.net/media/line_videos \
 /ad-hub.net/media/messageRequestChunks/pool

chmod -R 777 /ad-hub.net/media/

# Setup memcached
sed -i -e 's/\(^-l .*\)/#\1/g' /etc/memcached.conf
sed -i -e 's/\(^-m .*\)/#\1\n-m 1024/g' /etc/memcached.conf
sed -i -e 's/\(^# -c .*\)/\1\n-c 8096/g' /etc/memcached.conf

systemctl restart memcached.service
systemctl enable memcached.service

# Setup NFS
echo "/ad-hub.net       /export/ad-hub.net   none    bind    0       0" >> /etc/fstab
echo "/etc/letsencrypt  /export/letsencrypt  none    bind    0       0" >> /etc/fstab

mount -a

echo "/export             10.19.0.0/16(rw,fsid=0,no_subtree_check,sync)" >> /etc/exports
echo "/export/ad-hub.net  10.19.0.0/16(rw,nohide,insecure,no_root_squash,no_subtree_check,sync)" >> /etc/exports
echo "/export/letsencrypt 10.19.0.0/16(rw,nohide,insecure,no_root_squash,no_subtree_check,sync)" >> /etc/exports

systemctl restart nfs-*

# Setup Fluentd
curl -L https://toolbelt.treasuredata.com/sh/install-ubuntu-bionic-td-agent3.sh | sh
cp /etc/td-agent/td-agent.conf /etc/td-agent/td-agent.conf.bk
mkdir -p /var/log/fluent
chown -R td-agent.td-agent /var/log/fluent
apt-get install -y make libcurl4-gnutls-dev --yes
apt-get install -y build-essential
td-agent-gem install -y fluent-plugin-azure-loganalytics

cat << EOF > /etc/td-agent/td-agent.conf
<source>
   @type forward
   port 24224
   bind 0.0.0.0
   source_hostname_key fluent_client
</source>

<source>
   @type syslog
   port 5140
   bind 0.0.0.0
   tag system
</source>

<match acho.php-fpm.**>
   @type copy
   <store>
      @type file
      path /var/log/fluent/acho/php-fpm.%Y-%m-%d.%H%M
      append true
      compress gzip
      <buffer time>
         @type file
         path /var/log/fluent/buffer/php-fpm
         timekey     1d
         timekey_wait 1m
         flush_mode interval
         flush_interval 3
      </buffer>
   </store>
   <store>
      @type azure-loganalytics
      customer_id 1be3433b-480e-4826-9b1d-41a54e59ec9d
      shared_key cj5xgWJkNBoP9c7EgH/JZkfczLJJwOFyMWY0avAvrYj6096xh+H4v4gNilHgfhxD78ZJhp7dFk4ory6U9zXUgg==
      log_type AchoPhp
      time_format %Y-%m-%d %H:%M:%S
   </store>
</match>
<match acho.nginx.**>
   @type copy
   <store>
      @type file
      path /var/log/fluent/acho/nginx.%Y-%m-%d.%H%M
      append true
      compress gzip
      <buffer time>
         @type file
         path /var/log/fluent/buffer/nginx
         timekey     1d
         timekey_wait 1m
         flush_mode interval
         flush_interval 3
      </buffer>
   </store>
   <store>
      @type azure-loganalytics
      customer_id 1be3433b-480e-4826-9b1d-41a54e59ec9d
      shared_key cj5xgWJkNBoP9c7EgH/JZkfczLJJwOFyMWY0avAvrYj6096xh+H4v4gNilHgfhxD78ZJhp7dFk4ory6U9zXUgg==
      log_type AchoNginx
      time_format %Y-%m-%d %H:%M:%S
   </store>
</match>
<match acho.apps.**>
   @type copy
   <store>
      @type file
      path /var/log/fluent/acho/apps.%Y-%m-%d.%H%M
      append true
      compress gzip
      <buffer time>
         @type file
         path /var/log/fluent/buffer/apps
         timekey     1d
         timekey_wait 1m
         flush_mode interval
         flush_interval 3
      </buffer>
   </store>
   <store>
      @type azure-loganalytics
      customer_id 1be3433b-480e-4826-9b1d-41a54e59ec9d
      shared_key cj5xgWJkNBoP9c7EgH/JZkfczLJJwOFyMWY0avAvrYj6096xh+H4v4gNilHgfhxD78ZJhp7dFk4ory6U9zXUgg==
      log_type AchoApps
      time_format %Y-%m-%d %H:%M:%S
   </store>
</match>
<match acho.acho-java.**>
   @type copy
   <store>
      @type file
      path /var/log/fluent/acho/acho-java.%Y-%m-%d.%H%M
      append true
      compress gzip
      <buffer time>
         @type file
         path /var/log/fluent/buffer/acho-java
         timekey     1d
         timekey_wait 1m
         flush_mode interval
         flush_interval 3
      </buffer>
   </store>
   <store>
      @type azure-loganalytics
      customer_id 1be3433b-480e-4826-9b1d-41a54e59ec9d
      shared_key cj5xgWJkNBoP9c7EgH/JZkfczLJJwOFyMWY0avAvrYj6096xh+H4v4gNilHgfhxD78ZJhp7dFk4ory6U9zXUgg==
      log_type AchoJava
      time_format %Y-%m-%d %H:%M:%S
   </store>
</match>

<match acho.**>
   @type copy
   <store>
      @type file
      path /var/log/fluent/acho/other.%Y-%m-%d.%H%M
      append true
      compress gzip
      <buffer time>
         @type file
         path /var/log/fluent/buffer/acho
         timekey     1d
         timekey_wait 1m
         flush_mode interval
         flush_interval 3
      </buffer>
   </store>
   <store>
      @type azure-loganalytics
      customer_id 1be3433b-480e-4826-9b1d-41a54e59ec9d
      shared_key cj5xgWJkNBoP9c7EgH/JZkfczLJJwOFyMWY0avAvrYj6096xh+H4v4gNilHgfhxD78ZJhp7dFk4ory6U9zXUgg==
      log_type AchoOthers
      time_format %Y-%m-%d %H:%M:%S
   </store>
</match>

<match **>
   @type copy
   <store>
      @type file
      path /var/log/fluent/other.%Y-%m-%d.%H%M
      append true
      compress gzip
      <buffer time>
         @type file
         path /var/log/fluent/buffer
         timekey     1d
         timekey_wait 1m
         flush_mode interval
         flush_interval 3
      </buffer>
   </store>
   <store>
      @type azure-loganalytics
      customer_id 1be3433b-480e-4826-9b1d-41a54e59ec9d
      shared_key cj5xgWJkNBoP9c7EgH/JZkfczLJJwOFyMWY0avAvrYj6096xh+H4v4gNilHgfhxD78ZJhp7dFk4ory6U9zXUgg==
      log_type Others
      time_format %Y-%m-%d %H:%M:%S
   </store>
</match>
EOF

systemctl restart td-agent.service
systemctl enable td-agent.service

# Change IP of vmss-external-server in docker-compose.yaml
sed -i -e \
  "$(echo 's/\(\s*- "vmss-external-server:\)[^"]*"/\1'$(hostname -I | awk '{ print $1 }')'"/g')" \
  /ad-hub.net/docker-service/docker-compose.yaml

echo 
echo "======= Setup completed ======="
echo 