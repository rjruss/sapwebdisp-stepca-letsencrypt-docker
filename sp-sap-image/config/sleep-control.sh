#!/bin/bash

. shared_logging.sh


main () {

if [[ "${1}" == "" ]];then
        
    while true;do
        control_time=$(cat /srv/usr/sap/webdisp/manage/control_date_renew_certs )
        current_epoc_time=$(date +%s)
        if [[ ${current_epoc_time} -ge ${control_time} ]];then
            date -d "next $(cat /srv/usr/sap/webdisp/manage/control_day) $(cat /srv/usr/sap/webdisp/manage/control_time)" +%s > /srv/usr/sap/webdisp/manage/control_date_renew_certs 
            loginfo "Current time ${current_epoc_time} at renew certificate time ${control_time}"
            exit 0
        else
            loginfo "Sleeping at $(date  +"%d/%m/%Y %H:%M:%S ") every $(cat /srv/usr/sap/webdisp/manage/control_sleep) until $(date -d @$(cat /srv/usr/sap/webdisp/manage/control_date_renew_certs) +"%d-%m-%Y %H:%M:%S ") "
            sleep "$(cat /srv/usr/sap/webdisp/manage/control_sleep )"
        fi
        check_cert.sh
    done
else
    logerr "expecting only 'display' , 'change', 'change_check_days_to_expire', 'renew_certs_days_length' or 'sleep_interval' passed to this command - and no passed parameters is only used in the background setup "
    exit 3
fi

}



change_check_date () {

if [[ $(date -d "${1}" +%u) =~ ^[1-7]$ ]]; then
    echo "${1}" > /srv/usr/sap/webdisp/manage/control_day
else
    logerr "Invalid dayname, expecting Monday, Tuesday etc format"
    exit 1
fi


if [[ "${2}" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "${2}" > /srv/usr/sap/webdisp/manage/control_time
else
    logerr "Invalid time format. Please enter a time in HH:MM format (24-hour clock)."
    exit 2
fi

date -d "this $(cat /srv/usr/sap/webdisp/manage/control_day) $(cat /srv/usr/sap/webdisp/manage/control_time)" +%s > /srv/usr/sap/webdisp/manage/control_date_renew_certs 
loginfo "Renew certificate check time set for $(date -d @$(cat /srv/usr/sap/webdisp/manage/control_date_renew_certs) +"%d-%m-%Y %H:%M:%S ")"

}

update_sleep_interval () {

    if [[ "${1}" =~ ^[0-9]+([smhd]?)$ ]]; then
        echo "Updating sleep duration to : ${1}"
        echo "${1}" > /srv/usr/sap/webdisp/manage/control_sleep
    else
        logerr "Invalid sleep duration: ${1} - expecting seconds, minutes or hours etc e.g. 10, 10m, 10h etc"
    fi

}

update_cert_valid_days_check () {

    if [[ "${1}" =~ ^[0-9]+$ ]]; then
        loginfo "The system will now be set to check for certificate expiration ${1} before it expires."
        echo "${1}" > /srv/usr/sap/webdisp/manage/control_cert_check_days
    else
        logerr "${1} is not a valid integer ignoring value and check is still at $( cat /srv/usr/sap/webdisp/manage/control_cert_check_days ) days. "
    fi

}

update_cert_days () {

    if [[ "${1}" =~ ^[0-9]+$ ]]; then
        loginfo "The system will now generate a certificate valid for ${1} days."
        echo "${1}" > /srv/usr/sap/webdisp/manage/control_cert_renew_length
    else
        logerr "${1} is not a valid integer ignoring value and days valid still at $( cat /srv/usr/sap/webdisp/manage/control_cert_renew_length ) days. "
    fi


}

case ${1} in
    display) 
        
        echo -e "Wake up time to check certificate :${SP_BOLD} $(date -d @$(cat /srv/usr/sap/webdisp/manage/control_date_renew_certs) +"%d-%m-%Y %H:%M:%S ") ${SP_RESET}"
        echo -e "Sleep interval :${SP_BOLD} $(cat /srv/usr/sap/webdisp/manage/control_sleep )${SP_RESET}"
        echo -e "Days remaining for certificate expiry check :${SP_BOLD} $(cat /srv/usr/sap/webdisp/manage/control_cert_check_days )${SP_RESET}"
        echo -e "Length in days a new certificate is valid for :${SP_BOLD} $(cat /srv/usr/sap/webdisp/manage/control_cert_renew_length )${SP_RESET}"
        echo 
        echo "options for this script"
        grep  ")$" /srv/usr/sap/webdisp/manage/sleep-control.sh |grep "^    [a-z]"
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
        main "${1}"
    ;;
esac


