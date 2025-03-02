#!/bin/bash

. ./sp-sap-image/config/shared/shared_logging.sh

loop_containers () {
    find -name "start*sh" -exec grep -l "sleep-control.sh" {} \; |awk -F\/ '{print $2}' |sed "s/^sp-//;s/$/-run/"
}

change_check_date () {

        if [[ ! $(date -d "${1}" +%u) =~ ^[1-7]$ ]]; then
            logerr "Invalid dayname, expecting Monday, Tuesday etc format"
            exit 1
        fi


        if [[ ! "${2}" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
            logerr "Invalid time format. Please enter a time in HH:MM format (24-hour clock)."
            exit 2
        fi

        while read c
        do
            echo "${c}"
            docker exec  "${c}" sleep-control.sh change "${1}" "${2}"
        done < <(loop_containers)

}

update_sleep_interval () {

    if [[ "${1}" =~ ^[0-9]+([smhd]?)$ ]]; then
        while read c
        do
            echo "${c}"
            docker exec  "${c}" sleep-control.sh sleep_interval "${1}" 
        done < <(loop_containers)
    else
        logerr "Invalid sleep duration: ${1} - expecting seconds, minutes or hours etc e.g. 10, 10m, 10h etc"
    fi

}

update_cert_valid_days_check () {


    if [[ "${1}" =~ ^[0-9]+$ ]]; then

        while read c
        do
            echo "${c}"
            docker exec  "${c}" sleep-control.sh change_check_days_to_expire "${1}" 
        done < <(loop_containers)

    else
        logerr "${1} is not a valid integer ignoring value and check is still at $( cat /srv/usr/sap/webdisp/manage/control_cert_check_days ) days. "
    fi

}

update_cert_days () {



    if [[ "${1}" =~ ^[0-9]+$ ]]; then
        while read c
        do
            echo "${c}"
            docker exec  "${c}" sleep-control.sh renew_certs_days_length "${1}" 
        done < <(loop_containers)
    else
        logerr "${1} is not a valid integer ignoring value and days valid still at $( cat /srv/usr/sap/webdisp/manage/control_cert_renew_length ) days. "
    fi


}

case ${1} in
    display) 
        
        while read c
        do
            loginfo "---${BOLD}start of display for ${c}${RESET}"
            docker exec  "${c}" sleep-control.sh display
            loginfo "---end of display for ${c}"
            echo
        done < <(loop_containers)

    ;;
    change)
        
        change_check_date "${2}" "${3}"
        
    ;;
    sleep_interval)
        
        update_sleep_interval "$2"
        
    ;;
    change_check_days_to_expire)
        
        update_cert_valid_days_check "$2"
        
    ;;
    renew_certs_days_length)
        
        update_cert_days "$2"
        
    ;;
    *)
        loginfo "wrong option - try again"
        echo "options for this script"
        grep  ")$" sleep-control-all.sh |grep "^    [a-z]"
    ;;
esac



