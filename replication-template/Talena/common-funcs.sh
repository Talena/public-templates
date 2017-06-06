#!/bin/bash

#
# This script will have function required 
# to prepare Talena node for installation
#

export LOG_FILE="/tmp/talena-azure-initialize.log"
export TALENA_ENV="/etc/talena/talena-env.sh"
export MOUNT_BASENAME="/talena/disk"
EXECNAME="common-funcs"

# logs everything to the $LOG_FILE
log() {
  echo "$(date) [${EXECNAME}]: $*" >> "${LOG_FILE}"
}

exit_function()
{
    local ret=$1
    log "Exiting with retcode : ${ret}"
    exit ${ret}
}

if [ ! -f "${TALENA_ENV}" ]
then
    log "ERROR: ${TALENA_ENV} not found."
    exit_function 1
fi

. ${TALENA_ENV}

start_rpyc()
{
    log "INFO: Starting RPyC"
    local rpyc_script="${INSTALL_DIR}/${TALENA_VERSION}/launch_rpyc.sh"
    if [ ! -f "${rpyc_script}" ]
    then
        log "ERROR: ${rpyc_script} not found."
        exit_function 1 
    fi  

    ${rpyc_script} 
    if [ $? -ne 0 ]
    then
        log "ERROR: Failed to start RPyC"
        return 1
    fi
}

prepare_unmounted_volumes()
{
  # Each line contains an entry like /dev/<device name>
  MOUNTED_VOLUMES=$(df -h | grep -o -E "^/dev/[^[:space:]]*")
  log "DEBUG: MOUNTED_VOLUMES=${MOUNTED_VOLUMES}"

  # Each line contains an entry like <device name> (no /dev/ prefix)
  # (This awk script prints the last field of every line with line number
  # greater than 2.)
  ALL_PARTITIONS=$(awk 'FNR > 2 {print $NF}' /proc/partitions)
  log "DEBUG: ALL_PARTITIONS=${ALL_PARTITIONS}"

  COUNTER=1
  for part in $ALL_PARTITIONS
  do
      # If this partition does not end with a number (likely a partition of a
      # mounted volume), is not equivalent to the alphabetic portion of another
      # partition with digits at the end (likely a volume that has already been
      # mounted), and is not contained in $MOUNTED_VOLUMES
      if [[ ! ${part} =~ [0-9]$ && ! ${ALL_PARTITIONS} =~ $part[0-9] && $MOUNTED_VOLUMES != *$part* ]];then
          log "INFO: Preparing device:/dev/$part, mount:${MOUNT_BASENAME}${COUNTER}"
          if prepare_disk "${MOUNT_BASENAME}${COUNTER}" "/dev/$part"
          then
               COUNTER=$(($COUNTER+1))
         fi
      fi
  done
  wait # for all the background prepare_disk function calls to complete
}

prepare_disk()
{
  local mount=$1
  local device=$2
  local ret=0 

  FS=ext4
  FS_OPTS="-E lazy_itable_init=1"

  which mkfs.$FS
  # Fall back to ext3
  if [[ $? -ne 0 ]]; then
    FS=ext3
    FS_OPTS=""
  fi

  # is device mounted?
  mount | grep -q "${device}"
  if [ $? == 0 ]; then
      log "INFO: $device is mounted"
  else
      log "WARN: ERASING CONTENTS OF $device"
      mkfs.$FS -F $FS_OPTS $device -m 0 

      # If $FS is ext3 or ext4, then run tune2fs -i 0 -c 0 to disable fsck checks for data volumes

      if [ $FS = "ext3" -o $FS = "ext4" ]; then
      /sbin/tune2fs -i0 -c0 ${device} 
      fi
      log "INFO: Mounting $device on $mount" 
      if [ ! -e "${mount}" ]; then
        mkdir -p "${mount}"
      fi
      # gather the UUID for the specific device

      blockid=$(/sbin/blkid|grep ${device}|awk '{print $2}'|awk -F\= '{print $2}'|sed -e"s/\"//g")

      #mount -o defaults,noatime "${device}" "${mount}"

      # Set up the blkid for device entry in /etc/fstab

      echo "UUID=${blockid} $mount $FS defaults 0 0" >> /etc/fstab
      mount ${mount}
      if [ $? -ne 0 ]
      then
          log "ERROR: mount failed for ${mount}"
          ret=1
      fi
  fi
  return ${ret} 
}

disable_firewall()
{
   log "INFO: Stopping firewalld"
   systemctl disable firewalld
   systemctl stop firewalld     
}

set_hostname_to_fqdn()
{
    # Set host FQDN
    myhostname=$(hostname)
    fqdnstring=$(python -c "import socket; print socket.getfqdn('$myhostname')")
    log "INFO: Set host FQDN to ${fqdnstring}"
    sed -i "s/.*myhostname.*/${fqdnstring}/g" /etc/hostname
    sed -i "s/.*HOSTNAME.*/HOSTNAME=${fqdnstring}/g" /etc/sysconfig/network
    /etc/init.d/network restart
}

update_etc_hosts()
{
    local nodeCount=$1
    local vmName=$2   

    log "INFO: Updating /etc/hosts" 
    let nodeCount=${nodeCount}-1
    for i in `eval echo {0..$nodeCount}`
    do
        nodeName="${vmName}${i}" 
        ipAddr=$(python -c "import socket; print socket.gethostbyname('$nodeName')")
        if [ $? -eq 0 ]
        then
            log "DEBUG: Adding ipAddr=${ipAddr} nodeName=${nodeName} to /etc/hosts"
            if [ ! -z "${ipAddr}" ]
            then
                echo "${ipAddr} ${nodeName}" >>/etc/hosts
            fi
        fi 
    done
}

prepare_talena_node()
{
    log "INFO: Preparing Talena node - start"
    local ret=0
    local nodecount=$1
    local vmbasename=$2

    disable_firewall
    set_hostname_to_fqdn
    update_etc_hosts ${nodecount} ${vmbasename} 
    let ret=${ret}+$? 
 
    start_rpyc
    let ret=${ret}+$? 

    prepare_unmounted_volumes
    let ret=${ret}+$?

    log "INFO: Preparing Talena node - end"
    return ${ret} 
}

