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
    # PS1="\[\033[1;33m\]\[\033[1;41m\][PRO!]\[\033[40m\] \u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]: \[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]"
    # PS1="\[\033[1;33m\]\u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]:\[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]"
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
    git clone https://github.com/kelly4286/kubernetes.git -b k8s
    cp -a kubernetes/* /ad-hub.net/
    rm -rf kubernetes
   
    # 安裝 External Services
    ./ad-hub.net/scripts/setup_external_server.sh
    az login
    reboot
      
    # 記得複製 /root/.ssh/id_rsa.pub 到 gogs 上的 Deploy Keys
    ```

5. 建立 Kubernetes Service
   - Kubernetes cluster name: adHubK8sTest
   - 位置: (亞太地區) 日本東部
   - Node size:  待定
   - Node count:  待定
   - Scale / Virtual nodes: Disabled
   - Scale / VM scale sets: Enabled
   - Enable RBAC: 是
   - 網路 / Network configuration: Advanced
   - 網路 / Virtual network: adHub_Azure_10.19
   - 網路 / Cluster subnet: adhub-k8s-jp-subnet (10.19.16.0/20)
   - 網路 / Kubernetes service address range: 10.0.0.0/16
   - 網路 / Kubernetes DNS service IP address: 10.0.0.10
   - 網路 / Docker Bridge address: 172.17.0.1/16
   - 網路 / DNS name prefix: adHubK8sTest-dns
   - 網路 / Private cluster: Disabled
   - 網路 / Network policy: Azure
   - 網路 / HTTP application routing: 否

6. 在外部虛擬機器架設 Kubernetes 環境

    ```sh
    # 安裝 kubectl
    curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    kubectl version --client
    
    # 登入 Azure Cloud
    az login
   
    # 登入 Container Registry
    docker login -u adhub -p 'voYi8whxWjm8izOTEABPWw=R49j=JAGY' adhub.azurecr.io
    az acr login --name adhub
   
    # 取得 Kubernetes 叢集認證
    az aks get-credentials --resource-group adHub_KubernetesTest --name adHubK8sTest
   
    # 將 K8S 與 Container Registry 建立連結 (需要跑一陣子)
    az aks update -n adHubK8sTest -g adHub_KubernetesTest --attach-acr adhub
   
    ########(使用 Azure File Share 才需要) 建立 Kubernetes Secret 並儲存在某個 Storage Account
    kubectl create secret generic azure-secret --from-literal azurestorageaccountname=ahstorageaccount --from-literal azurestorageaccountkey="04YYW93U5jDlY3jwODY2KOPoIKdv9v//wd5BhfdTwrDBSNs5Z7bkb//pJ7qTtj1XWRpJXoCCquoy9d7hwGZy3A==" --type=Opaque
    
    ########(使用 Azure File Share 才需要) 建立 Azure File Share PV and PVC
    kubectl apply -f azure-pv.yaml
   
    ## 建立 NFS PV and PVC
    kubectl apply -f nfs-pv-pvc.yaml
    
    ## Deploy App
    kubectl apply -f acho-web.yaml

    
    ```
   
   