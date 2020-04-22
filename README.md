#adHub Kubernetes

##Setup

1. 建立 Container Registry
2. 建立 Kubernetes Service
3. 建立外部虛擬機器
   - 映像檔：Ubuntu Server 18.04 LTS
   - 區域：(亞太地區) 日本東部
   - 大小：標準 F4s
   - 驗證類型：密碼, adhub / ....
   - 新增 Data 磁碟：128 GiB (標準 HDD)
   - 新增 Log 磁碟：32 GiB (標準 HDD)
   - 網路介面：adHub_Azure_10.19 / adhub-vmss-jp-subnet (10.19.32.0/20) / 公用 IP 設成"無"
   - 確認加速的網路是開啟的
   - 建立 VM

4. 設定虛擬機器外掛的磁碟
   - 登入新建的主機 `ssh adhub@ah-t-ext01.XXX`
   - 在新建主機執行下列指令

    ```sh
    # 切換到 root
    sudo -i
   
    # 設定 bash color
    # PS1="\[\033[1;33m\]\[\033[1;41m\][WARNING!!這台是PROD!!]\[\033[40m\] \u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]:\[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]"
    # PS1="\[\033[40m\] \u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]:\[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]"
    vim /root/.bashrc

    # 設定 Timezone
    timedatectl set-timezone Asia/Taipei

    # 確認外掛硬碟是哪個 (可以看容量，通常是最後一個)
    fdisk -l

    # 確定外掛的 Data 硬碟是哪個後(通常是 /dev/sdc )，用 parted 進行切割
    parted -a optimal /dev/sdc mklabel msdos
    parted -a optimal /dev/sdc mkpart primary ext4 0% 100%

    # 確定外掛的 Log 硬碟是哪個後(通常是 /dev/sdd )，用 parted 進行切割
    parted -a optimal /dev/sdd mklabel msdos
    parted -a optimal /dev/sdd mkpart primary ext4 0% 100%

    # 格式化新的分割區
    mkfs -t ext4 /dev/sdc1
    mkfs -t ext4 /dev/sdd1

    # 建立掛載目錄
    mkdir /ad-hub.net
    mkdir /var/log/fluent

    # 找出新分割區的 UUID
    # 32G 沒有 mount point 的是 Log Disk, 256G 沒有 mount point 的是 Data Disk
    lsblk --output NAME,SIZE,TYPE,UUID,MOUNTPOINT

    # 設定到 /etc/fstab，內容會像是下面這行，但 UUID 要換成真實對應的 UUID
    # UUID=aadce4e4-67a2-4f59-a6b5-520a42aba1b8          /ad-hub.net     ext4    defaults    1 2
    # UUID=e960a523-f914-443b-99b9-5f2f932d8dd5          /var/log/fluent ext4    defaults    1 2
    vim /etc/fstab

    # 掛載並確認
    mount -a
    df -h

    # 把這個專案放到 /ad-hub.net
    git clone https://github.com/kelly4286/kubernetes.git
    cp -a kubernetes/* /ad-hub.net/
    rm -rf kubernetes
   
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

    ### Install Dependencies
    apt update
    apt install -y jq make memcached nfs-kernel-server software-properties-common
    ### Install Nodejs
    curl -sL https://deb.nodesource.com/setup_8.x | bash -
    apt-get install -y nodejs
    ### Install Azure CLI
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    ### Install Docker
    apt-get remove docker docker-engine containerd runc
    apt-get update
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common \
        docker.io
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    apt-key fingerprint 0EBFCD88
    add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    ### Generate media folders
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
   
    ### Setup memcached
    sed -i -e 's/\(^-l .*\)/#\1/g' /etc/memcached.conf
    sed -i -e 's/\(^-m .*\)/#\1\n-m 1024/g' /etc/memcached.conf
    sed -i -e 's/\(^# -c .*\)/\1\n-c 8096/g' /etc/memcached.conf
    systemctl restart memcached.service
    systemctl enable memcached.service
   
    ### Setup NFS
    echo "/ad-hub.net       /export/ad-hub.net   none    bind    0       0" >> /etc/fstab
    mount -a
    echo "/export             10.240.0.0/16(rw,fsid=0,no_subtree_check,sync)" >> /etc/exports
    echo "/export/ad-hub.net  10.240.0.0/16(rw,nohide,insecure,no_root_squash,no_subtree_check,sync)" >> /etc/exports
    systemctl restart nfs-*
   
    ### Setup Fluentd
    curl -L https://toolbelt.treasuredata.com/sh/install-ubuntu-bionic-td-agent3.sh | sh
    cp /etc/td-agent/td-agent.conf /etc/td-agent/td-agent.conf.bk
    mkdir -p /var/log/fluent
    chown -R td-agent.td-agent /var/log/fluent
    apt-get install -y make build-essential libcurl4-gnutls-dev
    td-agent-gem install fluent-plugin-azure-loganalytics
   
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
             timekey 1d
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
             timekey 1d
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
             timekey 1d
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
             timekey 1d
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
             timekey 1d
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
             timekey 1d
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
   
    ########(Skipped) 設定 Azure File Share
    sudo mkdir /mnt/ahstorageaccount
    if [ ! -d "/etc/smbcredentials" ]; then
    sudo mkdir /etc/smbcredentials
    fi
    if [ ! -f "/etc/smbcredentials/ahstorageaccount.cred" ]; then
        sudo bash -c 'echo "username=ahstorageaccount" >> /etc/smbcredentials/ahstorageaccount.cred'
        sudo bash -c 'echo "password=04YYW93U5jDlY3jwODY2KOPoIKdv9v//wd5BhfdTwrDBSNs5Z7bkb//pJ7qTtj1XWRpJXoCCquoy9d7hwGZy3A==" >> /etc/smbcredentials/ahstorageaccount.cred'
    fi
    sudo chmod 600 /etc/smbcredentials/ahstorageaccount.cred
    
    sudo bash -c 'echo "//ahstorageaccount.file.core.windows.net/acho-file-share /ad-hub.net-fs cifs nofail,vers=3.0,credentials=/etc/smbcredentials/ahstorageaccount.cred,dir_mode=0777,file_mode=0777,serverino,mfsymlinks" >> /etc/fstab'
    sudo mount -t cifs //ahstorageaccount.file.core.windows.net/acho-file-share /ad-hub.net-fs -o vers=3.0,credentials=/etc/smbcredentials/ahstorageaccount.cred,dir_mode=0777,file_mode=0777,serverino,mfsymlinks

    ```

5. 架設 Kubernetes 環境

    ```sh
    # 安裝 kubectl
    curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    kubectl version --client
    
    # 登入 Azure Cloud
    az login
   
    # 登入 Container Registry
    docker login -u adhubtest -p 'sCoQUFRhbd4VxTHsnQsE6FUXnBoV2+QH' adhubtest.azurecr.io
    az acr login --name adhubtest --subscription "IUR 12000 Sponsorship ends 20180415"
   
    # 取得 Kubernetes 叢集認證
    az aks get-credentials --resource-group adHub-KubernetesTest --name ahK8sCluster
   
    # 將 K8S 與 Container Registry 建立連結 (需要跑一陣子)
    az aks update -n ahK8sCluster -g adHub-KubernetesTest --attach-acr adhubtest
   
    ########(使用 Azure File Share 才需要) 建立 Kubernetes Secret 並儲存在某個 Storage Account
    kubectl create secret generic azure-secret --from-literal azurestorageaccountname=ahstorageaccount --from-literal azurestorageaccountkey="04YYW93U5jDlY3jwODY2KOPoIKdv9v//wd5BhfdTwrDBSNs5Z7bkb//pJ7qTtj1XWRpJXoCCquoy9d7hwGZy3A==" --type=Opaque
    
    ########(使用 Azure File Share 才需要) 建立 Azure File Share PV and PVC
    kubectl apply -f azure-pv.yaml
   
    ## 建立 NFS PV and PVC
    kubectl apply -f nfs-pv-pvc.yaml
    
    ## Deploy App
    kubectl apply -f acho-web.yaml

    
    ```
   
   