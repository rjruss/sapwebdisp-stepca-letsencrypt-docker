#!/bin/bash


log() {
    sev=$1
    shift
    msg="$@"
    ts=$(date +"%Y/%m/%d %H:%M:%S")
    echo -e "$ts : $sev : $msg"
}

loginfo() {
    log "INFO" "$@"
}

logwarn() {
    log "${SP_BOLD}WARNING${SP_RESET}" "$@"
}

logerr() {
    log "${SP_BOLD}ERROR${SP_RESET}" "$@"
}
