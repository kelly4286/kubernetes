#!/bin/bash

read -p "Input the environment for this external server (default: dev) [vmss-pro|vmss-test|dev]:" VMSS_ENV
read -p "Run initial setup? [y/N]:"  -n 1 -r
printf "\nVMSS_ENV=$VMSS_ENV\n"

if [[ $REPLY =~ ^[Yy]$ ]]; then
   SETUP_INITIAL="T"
else
   SETUP_INITIAL="F"
fi

if [ "${VMSS_ENV}" == "vmss-pro" ]; then
   LOGANALYTICS_SHARED_KEY="HwFEoDhIV1zN7YA6KAzT5kvDT6/ssPVxOPJ5rNqoOUSz6AwhPwUkq8/3ykgK5qoL2RmwYhVv/Tnp+vh1mYqGeg=="
   LOGANALYTICS_CUSTOMER_ID="e06f1977-c759-4012-b592-c5a3fe60b777"
   BASHRC_PS1_COLOR="\[\033[1;33m\]\[\033[1;41m\][PRO!]\[\033[40m\] \u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]: \[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]"
else
   LOGANALYTICS_SHARED_KEY="cj5xgWJkNBoP9c7EgH/JZkfczLJJwOFyMWY0avAvrYj6096xh+H4v4gNilHgfhxD78ZJhp7dFk4ory6U9zXUgg=="
   LOGANALYTICS_CUSTOMER_ID="1be3433b-480e-4826-9b1d-41a54e59ec9d"
   BASHRC_PS1_COLOR="\[\033[1;33m\]\u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]:\[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]"
fi

set -eux

# Generate key
if [[ ${SETUP_INITIAL} =~ ^[T]$ ]]; then
   ssh-keygen -t rsa -b 2048 -C "${USER}@$(hostname -I | awk '{ print $1 }')"
   cp /root/.ssh/id_rsa.pub /ad-hub.net/docker-service/ext-id_rsa.pub
fi

apt update
apt install -y jq make memcached nfs-kernel-server software-properties-common

# Install Mail
echo "postfix postfix/mailname string support@ad-hub.net" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
apt-get install -y mailutils

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

curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

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
systemctl stop memcached.service; systemctl disable memcached.service;
systemctl stop memcached@general.service; systemctl disable memcached@general.service; systemctl stop memcached@session.service; systemctl disable memcached@session.service;
rm -rf /etc/memcached.conf; rm -rf /etc/memcached.d; rm -rf /etc/systemd/system/memcached@.service;
mkdir -p /etc/memcached.d
ln -s /ad-hub.net/external-service/config/memcached/memcached_general.conf /etc/memcached.d/memcached_general.conf
ln -s /ad-hub.net/external-service/config/memcached/memcached_session.conf /etc/memcached.d/memcached_session.conf
cp /ad-hub.net/external-service/config/memcached/memcached@.service /etc/systemd/system/memcached@.service
systemctl daemon-reload
systemctl start memcached@general.service; systemctl enable memcached@general.service; systemctl start memcached@session.service; systemctl enable memcached@session.service;

# Setup NFS
if [[ ${SETUP_INITIAL} =~ ^[T]$ ]]; then
   echo "/ad-hub.net       /export/ad-hub.net   none    bind    0       0" >> /etc/fstab
   echo "/etc/letsencrypt  /export/letsencrypt  none    bind    0       0" >> /etc/fstab

   mount -a

   echo "/export             10.19.0.0/16(rw,fsid=0,no_subtree_check,sync)" >> /etc/exports
   echo "/export/ad-hub.net  10.19.0.0/16(rw,nohide,insecure,no_root_squash,no_subtree_check,sync)" >> /etc/exports
   echo "/export/letsencrypt 10.19.0.0/16(rw,nohide,insecure,no_root_squash,no_subtree_check,sync)" >> /etc/exports

   systemctl restart nfs-*
fi

# Setup Swap
if [[ ${SETUP_INITIAL} =~ ^[T]$ ]]; then
   fallocate -l 4G /mnt/swapfile
   chmod 600 /mnt/swapfile
   mkswap /mnt/swapfile
   swapon /mnt/swapfile
   echo "/mnt/swapfile    none    swap    sw    0    0" >> /etc/fstab
fi

# Setup crontab
crontab /ad-hub.net/external-service/config/crontab/crontab

# Setup Fluentd
curl -L https://toolbelt.treasuredata.com/sh/install-ubuntu-bionic-td-agent3.sh | sh;
cp /etc/td-agent/td-agent.conf /etc/td-agent/td-agent.conf.bk
mkdir -p /var/log/fluent
chown -R td-agent.td-agent /var/log/fluent
apt-get install -y make build-essential libcurl4-gnutls-dev
td-agent-gem install fluent-plugin-azure-loganalytics

# Setup Fluentd config
sed -i -e "s/customer_id.*/customer_id ${LOGANALYTICS_CUSTOMER_ID}/g" /ad-hub.net/external-service/config/td-agent/td-agent.conf
sed -i -e "s/shared_key.*/shared_key $(printf '%s\n' "$LOGANALYTICS_SHARED_KEY" | sed 's:[\/&]:\\&:g;$!s/$/\\/')/g" /ad-hub.net/external-service/config/td-agent/td-agent.conf
rm -rf /etc/td-agent/td-agent.conf
ln -s /ad-hub.net/external-service/config/td-agent/td-agent.conf /etc/td-agent/td-agent.conf

systemctl restart td-agent.service
systemctl enable td-agent.service

# Change IP of vmss-external-server in docker-compose.yaml
sed -i -e \
   "$(echo 's/\(\s*- "vmss-external-server:\)[^"]*"/\1'$(hostname -I | awk '{ print $1 }')'"/g')" \
   /ad-hub.net/docker-service/docker-compose.yaml

# Login adhub.azurecr.io
docker login -u adhub -p 'voYi8whxWjm8izOTEABPWw=R49j=JAGY' adhub.azurecr.io
rm -rf /usr/local/sbin/ah-docker
ln -s /ad-hub.net/scripts/ah-docker.sh /usr/local/sbin/ah-docker
/usr/local/sbin/ah-docker up -d

# Setup vmss script
rm -rf /usr/local/sbin/vmss
ln -s /ad-hub.net/scripts/vmss.sh /usr/local/sbin/vmss

# Setup bash color and environments
cat << EOF >> /root/.bashrc

PS1="${BASHRC_PS1_COLOR}"
EOF

cat << EOF >> /home/adhub/.bashrc

PS1="${BASHRC_PS1_COLOR}"
EOF

cat << EOF >> /etc/profile

export ENABLE_CROND=yes
export VMSS_ENV=${VMSS_ENV}
EOF

## Setup root permission constraint
rm -rf /etc/sudoers.d/99-root-constraint
ln -s /ad-hub.net/external-service/config/sudoers.d/99-root-constraint /etc/sudoers.d/99-root-constraint

# Setup git alias
## 讓 git 指令的輸出結果加上顏色
git config --global color.ui true
git config --global core.autocrlf input

## 設定指令的別名
git config --global alias.co checkout
git config --global alias.ci commit
git config --global alias.st status
git config --global alias.br branch
git config --global alias.di diff
git config --global alias.lg "log --all --graph --abbrev-commit --date-order --pretty=format:'%C(bold yellow)%h%C(reset) - %C(bold cyan)%ci%C(reset) %C(bold green)%aN%C(reset) %C(white)%s%C(reset)%C(bold red)%d%C(reset)'"

if [[ ${SETUP_INITIAL} =~ ^[F]$ ]]; then
   printf "\n==================== Remind ====================\nRemember to check the following items manually:\n  - ssh key: /root/.ssh/id_rsa.pub\n  - nfs: systemctl status nfs-*\n  - swap: free -h\n\n\n"
fi

printf "\n======= Setup completed =======\n"