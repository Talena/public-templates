#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source ${SCRIPT_DIR}/common-funcs.sh
source ${TALENA_ENV}
EXECNAME="prepare-slave-node"
NODE_COUNT=
VM_BASENAME=

# logs everything to the $LOG_FILE
log() {
  echo "$(date) [${EXECNAME}]: $*" >> "${LOG_FILE}"
}

parse_arguments()
{
    while [ "$1" != "" ]; do
        case $1 in
            -nodeCount) shift
                NODE_COUNT="$1"
                log "DEBUG: NODE_COUNT=${NODE_COUNT}"  
                ;;
            -vmBasename) shift
                VM_BASENAME="$1"
                log "DEBUG: VM_BASENAME=${VM_BASENAME}"
                ;;
        esac
        shift
    done
    
    if [ -z "${NODE_COUNT}" -o -z "${VM_BASENAME}" ]
    then
        log "ERROR: No values found for -nodeCount/-vmBasename"
        exit_function 1   
    fi
}


echo "log location : ${LOG_FILE}"
log "------------- Preparing slave node - start ------------"

parse_arguments $*

# start RPyC and mount disks
sudo bash -c "source ./common-funcs.sh; prepare_talena_node ${NODE_COUNT} ${VM_BASENAME}" >>${LOG_FILE} 2>&1
ret=$?

log "------------- Preparing slave node - end ---------------"

if [ ${ret} -ne 0 ]
then
    log "ERROR: Failed to prepare Talena slave node"
fi
exit_function ${ret}
