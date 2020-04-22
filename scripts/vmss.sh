#!/bin/bash
function vmss_help(){
    echo
    echo "Usage: vmss <COMMAND> <COMMAND_OPTIONS...>"
    echo
    echo "Commands:"
    echo -e "    help                        : Show this help message and exit."
    echo -e "    info                        : Get information about the VMSS."
    echo -e "    ips                         : List the IP address of each VMSS instance."
    echo -e "    run [<OPTIONS>]             : SSH to each VMSS instance or execute a command (<OPTIONS>) in each VMSS instance."
    echo -e "    scale <NUMBER>              : Change the number of VMs within the VMSS. (Note: Use \`\E[1;37;40mshutdown\E[0m\` to scale to 0.)"
    echo -e "    shutdown                    : Shutdown each of VMSS instance."
    echo -e "    update-initial-script       : Update the initial custom scripts for each VMSS instance."
    echo
    echo -e "    acho-release                : Execute \`\E[1;37;40macho-release\E[0m\` scripts in each Docker container."
    echo -e "    crontab <OPTIONS>           : Execute crontab command in external Docker container."
    echo -e "    nginx <OPTIONS>             : Execute nginx commands in each Docker container. Useful for the config reload: \`\E[1;37;40mnginx -s reload\E[0m\`."
    echo -e "    supervisor <OPTIONS>        : Execute \`\E[1;37;40msupervisorctl\E[0m\` command in each Docker container."
    echo -e "                                  See \E[4;37;40mhttp://supervisord.org/running.html#supervisorctl-actions\E[0m for more information."
    echo
    exit 1
}

if [ "$#" == 0 ] || [ "$1" = "help" ] || [ "$1" = "-h" ]; then
    vmss_help
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
    done
    stop_ssh_agent
}

function update_initial_script(){
    if [ -z ${VMSS_ENV} ]; then
        echo "[ERROR] VMSS_ENV is not set. Please setup the env variable 'VMSS_ENV' first."
        exit 0
    fi

    if [ ${VMSS_ENV} == "vmss-pro" ]; then
        bashrc_ps="\[\033[1;33m\]\[\033[1;41m\][PRO!]\[\033[40m\] \u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]: \[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]"
    else
        bashrc_ps="\[\033[1;33m\]\u\[\033[1;37m\]@\[\033[1;32m\]\h\[\033[1;37m\]:\[\033[1;31m\]\w \[\033[1;36m\]\$ \[\033[0m\]"
    fi

    script=$(cat /ad-hub.net/scripts/setup_vmss_instance.sh \
        | sed "s/<EXTERNAL_SERVER_IP>/$(hostname -I | awk '{ print $1 }')/g" \
        | sed "s/<VMSS_ENV>/${VMSS_ENV}/g" \
        | sed "s/<BASHRC_PS1>/$(printf '%s\n' "$bashrc_ps" | sed 's:[\/&]:\\&:g;$!s/$/\\/')/g" \
        | gzip -9 | base64 -w 0)

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

function acho_release(){
    ah-docker exec -T -e VMSS_ENV=${VMSS_ENV} php bash /etc/acho-scripts/acho-release.sh;
    printf "\n########## Restart php-fpm in external container ##########\n\n";
    ah-docker exec -T php supervisorctl restart php-fpm;
    printf "\n########## Restart php-fpm in vmss container ##########\n\n";
    vm_run ah-docker exec -T php supervisorctl restart php-fpm;
}

function exec_nginx(){
    vm_run ah-docker exec -T php nginx $*
}

function acho_crontab(){
    docker-compose -f /ad-hub.net/docker-service/docker-compose.yaml exec php crontab $*;
    docker-compose -f /ad-hub.net/docker-service/docker-compose.yaml exec -T php crontab -l > /ad-hub.net/docker-service/scripts/acho-crontab;
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
    
    "update-initial-script")
        update_initial_script
        ;;

    "shutdown")
        shutdown
        ;;

    "supervisor")
        exec_supervisor $*
        ;;

    "acho-release")
        acho_release
        ;;

    "nginx")
        exec_nginx $*
        ;;

    "crontab")
        acho_crontab $*
        ;;

    *)
        vmss_help
        ;;
esac
echo
exit 0

