#!/bin/sh

# Install Docker, Docker Compose and dependent packages
apt-get update
apt-get -y upgrade

apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

apt-key fingerprint 0EBFCD88

add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

apt-get update
apt-get -y install docker-ce

curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add ip of external server to /etc/hosts
echo "<EXTERNAL_SERVER_IP>  vmss-external-server" >> /etc/hosts

# Install Mail
echo "postfix postfix/mailname string support@ad-hub.net" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
apt-get install -y mailutils

# Setup NFS
apt-get install -y nfs-common

rm -f /etc/fstab.bak
cp /etc/fstab /etc/fstab.bak
grep -v 'ad-hub.net' /etc/fstab.bak > /etc/fstab
echo "vmss-external-server:/export/ad-hub.net  /ad-hub.net nfs _netdev,defaults,udp,noacl,nolock 0 0" >> /etc/fstab
echo "vmss-external-server:/export/letsencrypt /etc/letsencrypt nfs _netdev,defaults,udp,noacl,nolock 0 0" >> /etc/fstab

mkdir -p /ad-hub.net /etc/letsencrypt
mount -a

# Setup Swap
fallocate -l 4G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile
echo "/mnt/swapfile    none    swap    sw    0    0" >> /etc/fstab

## Crontab for disk usage checking
croncmd="/bin/sh /ad-hub.net/scripts/check_disk_usage.sh;"
cronjob="0 * * * * ${croncmd}"
( crontab -l | grep -v -F "${croncmd}" ; echo "${cronjob}" ) | crontab -

# Setup bash color and environments
cat << EOF >> /root/.bashrc

PS1="<BASHRC_PS1>"
export VMSS_ENV=<VMSS_ENV>
EOF

# Login
cat /ad-hub.net/docker-service/ext-id_rsa.pub > /root/.ssh/authorized_keys
docker login -u adhub -p 'voYi8whxWjm8izOTEABPWw=R49j=JAGY' adhub.azurecr.io

ln -s /ad-hub.net/scripts/ah-docker.sh /usr/local/sbin/ah-docker

#docker run --name kuard -d -p 80:8080 gcr.io/kuar-demo/kuard-amd64:blue
export VMSS_ENV=<VMSS_ENV>
/usr/local/sbin/ah-docker up -d
