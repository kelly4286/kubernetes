#!/bin/bash

if [ "$#" == 0 ]; then
    echo "Command usage: $0 <COMMAND> <COMMAND_OPTIONS...>"
    exit 1
fi

# Get Command
command=$1
shift

vmss_config=/ad-hub.net/scripts/vmss_config.sh
if [ -f "$vmss_config" ]; then
    source $vmss_config
fi

if [ -z "$resource_group" -o -z "$vmss_name" ]; then
    read -p "Input resource group of VMSS (e.g., adHub_VmssTestJP): " resource_group
    read -p "Input name of VMSS (e.g., VmssTestJP): " vmss_name
    echo resource_group=$resource_group > $vmss_config
    echo vmss_name=$vmss_name >> $vmss_config
    source $vmss_config
fi

# Function SSH Agent
function start_ssh_agent() {
    if [ -z "$SSH_AGENT_PID" ] || [ -z "$(ps -p ${SSH_AGENT_PID} -o pid=)" ]; then
        eval `ssh-agent`
        LAUNCH_SSH_SGENT_IN_PROCESS=$?
    fi
}

function add_key(){
    keyfile=/root/.ssh/id_rsa
    ssh-add -l |grep -q `ssh-keygen -lf ${keyfile}  | awk '{print $2}'` || ssh-add ${keyfile}
}

function stop_ssh_agent() {
    if [ "${LAUNCH_SSH_SGENT_IN_PROCESS}" == 0 ]; then
        eval `ssh-agent -k`
    fi
}

# Functions
function show_vmss_info(){
    az vmss show --resource-group ${resource_group} --name ${vmss_name} \
    | jq '
        {
            location: .location,
            resourceGroup: .resourceGroup,
            name: .name,
            vm_size: .sku.name,
            capacity: .sku.capacity ,
            provisioningState: .provisioningState
        }'
}

function scale_operation(){
    if [ "$#" -eq 1 ]; then
        if [ "$1" -eq "0" ]; then
            echo Please use \'shutdown\' to scale down to zero
            exit 0
        fi
        read -p "Are you sure you want to change the scale to ${1} ? [y/N] " -n 1 -r
        echo   # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            az vmss scale --resource-group ${resource_group} --name ${vmss_name} --new-capacity ${1}
        else
            echo Canceled!
        fi
    fi

    show_vmss_info
}

function get_vm_ips(){
    az vmss nic list --resource-group ${resource_group} --vmss-name ${vmss_name} \
    | jq  --raw-output '.[].ipConfigurations[0].privateIpAddress'
}

function vm_run(){
    command_options=$*
    ips=`get_vm_ips`

    start_ssh_agent
    add_key

    echo
    echo "Start run following command on each VM in VMSS."
    echo ${command_options}
    echo
    for ip in ${ips}
    do
        echo "###########################"
        echo "# VM IP: ${ip}"
        echo "###########################"
        echo "Try to connect to the VM... "

        ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            root@${ip} ${command_options}

        echo $?
        echo "Task finish in ${ip}"
        echo
        sleep 15
    done
    stop_ssh_agent
}

function update_initial_script(){
    script=$(cat /ad-hub.net/scripts/setup_vmss_instance.sh | sed "s/<EXTERNAL_SERVER_IP>/$(hostname -I | awk '{ print $1 }')/g" | gzip -9 | base64 -w 0)

    echo $script | base64 -di | gunzip
    echo
    read -p "Are you sure you want to update custom script of VMSS? [y/N] " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        az vmss extension set \
            --name customScript \
            --publisher Microsoft.Azure.Extensions \
            --resource-group $resource_group \
            --vmss-name $vmss_name \
            --settings '{"script": "'${script}'"}'
    else
        echo Canceled!
    fi
}

function shutdown(){
    read -p "[WARNING] Are you sure you want to shutdown VMSS ? [y/N] " -n 1 -r
    echo   # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        az vmss scale --resource-group ${resource_group} --name ${vmss_name} --new-capacity 0
    else
        echo Canceled!
    fi
}

function exec_supervisor(){
    if [ "$#" -gt 0 ]; then
        vm_run ah-docker exec -T php supervisorctl $*
    else
        echo "Please refer to Supervisord document. (http://supervisord.org/running.html#supervisorctl-actions)"
    fi
}

# Command dispatch
case "${command}" in
    "info")
        show_vmss_info
        ;;

    "scale")
        scale_operation $*
        ;;

    "ips")
        get_vm_ips
        ;;

    "run")
        vm_run $*
        ;;
    
    "update_initial_script")
        update_initial_script
        ;;

    "shutdown")
        shutdown
        ;;

    "supervisor")
        exec_supervisor $*
        ;;
esac
echo
exit 0

