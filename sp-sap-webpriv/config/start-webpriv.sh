#!/bin/bash

set -x
. shared_logging.sh
###############################
## ACtion - _CHANGE_TO_REQUIRED_APP_CERT_DUR_VARIABLE to the required Variable
## ACtion - Update INST_LOCFILE & CERT_LOCATION
#################################
HOST_FQDN="$(hostname -f)"

INST_LOCFILE="${SECUDIR}/DOCKERSSL.pse"
#SP_CONTAINER_NAME
CERT_LOCATION="/srv/.self"
CERT_NAME="webpriv"



check_priv_ca () {

        if [[ -f /srv/.self/rootCA.key ]] ; then
                return 0
        else
                return 1
        fi

}


startup () {

	loginfo "startup webdispatcher ###############"
        /srv/usr/sap/webdisp/sapwebdisp pf=/srv/usr/sap/webdisp/sapwebdisp.pfl  > /proc/1/fd/1 2>/proc/1/fd/2 &
        loginfo "wait 2"
        sleep 2

}

stopapp () {

	loginfo "stopping "
        pkill -P $$

}



setup_files () {
 
    if [[ ! -f /srv/usr/sap/webdisp/manage/control_day ]];then
        echo "${SP_RDAY}" > /srv/usr/sap/webdisp/manage/control_day
    fi

    if [[ ! -f /srv/usr/sap/webdisp/manage/control_time ]];then
        echo "${SP_RTIME}" > /srv/usr/sap/webdisp/manage/control_time
    fi

    if [[ ! -f /srv/usr/sap/webdisp/manage/control_sleep ]];then
        echo "${SP_RSLEEP}" > /srv/usr/sap/webdisp/manage/control_sleep
    fi

    if [[ ! -f /srv/usr/sap/webdisp/manage/control_cert_check_days ]];then
        echo "${SP_RCOUNT}" > /srv/usr/sap/webdisp/manage/control_cert_check_days
    fi

    if [[ ! -f /srv/usr/sap/webdisp/manage/control_cert_renew_length ]];then
        echo "${SP_RENEW_VALID}" > /srv/usr/sap/webdisp/manage/control_cert_renew_length
    fi
}


initialise_app () {

	loginfo "initial setup of application"
        setup_files
        date -d "next ${SP_RDAY} ${SP_RTIME}" +%s > /srv/usr/sap/webdisp/manage/control_date_renew_certs 
        sed -i "s/ZHOST_FQDN/${HOST_FQDN}/;s/ZWEBADM_PORT/${ZWEBADM_PORT}/" /srv/usr/sap/webdisp/security/data/icm_filter_rules.txt
        sed -i "s/ZSP_TARGET_HOST/${SP_TARGET_HOST}/;s/SP_ZSRCSRV/${SP_ZSRCSRV}/" /srv/usr/sap/webdisp/security/data/icm_filter_rules.txt
        sed -i "s/ZSP_TARGET_HOST:ZSP_TARGET_PORT/${SP_TARGET_HOST}:${SP_TARGET_PORT}/" /srv/usr/sap/webdisp/sapwebdisp.pfl
        sed -i "s/SP_ZSRCSRV/${SP_ZSRCSRV}/;s/ZWEBADM_PORT/${ZWEBADM_PORT}/" /srv/usr/sap/webdisp/sapwebdisp.pfl
	sed -i "s/ZWEB_HOST_PORT/${WEBPRIV_HOST_PORT}/g" /srv/usr/sap/webdisp/sapwebdisp.pfl
        /srv/usr/sap/webdisp/sapgenpse gen_pse -p ${SECUDIR}/DOCKERSSL.pse -x '' -r ${CSR_LOCATE} -k GN-dNSName:${HOST_FQDN} 'CN='"${HOST_FQDN}"', DNS='"${HOST_FQDN}"', C=GB'
        #"/srv/usr/sap/webdisp/sapgenpse seclogin -p ${SECUDIR}/DOCKERSSL.pse -x ${PIN} -O dwdadm"
        sleep 5
        ls -l ${SECUDIR}/DOCKERSSL.pse
        startup
        loginfo "sleep 10"
        sleep 10
        . self-sign.sh
        sleep 5
        #/srv/usr/sap/webdisp/manage/manage-sign.sh
        if [ "$SP_ABAP_SETUP" == "YES" ]
        then
                /srv/usr/sap/webdisp/manage/web-abap.sh
        fi
        stopapp
        sleep 5
        startup
 
}

sign_csr () {

        loginfo "sign csr"
	
}

import_pse_roots () {

	sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a ${CERT_LOCATION}/stepCA.pem 
	sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLS.pse -a ${CERT_LOCATION}/stepCA.pem
	sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -a ${CERT_LOCATION}/stepCA.pem

}


import_pse_certs () {
	>${CERT_LOCATION}/signed-cert-chain.pem
	cat ${CERT_LOCATION}/stepCA.pem ${SIGNED_CERT} >> ${CERT_LOCATION}/signed-cert-chain.pem
	sapgenpse import_own_cert  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -c ${CERT_LOCATION}/signed-cert-chain.pem
}

renew () {

        loginfo "checking certificate for renewal"
        . self-renew.sh
        return $?

}




config_file () {

	loginfo "config_file"



}



post_startup_init () {

	
        loginfo "post start initialisation actions"
        /srv/usr/sap/webdisp/manage/setwebadm.sh &
        sleep 5
        ## Import trusted own root cert
        #trust anchor /srv/usr/sap/webdisp/manage/rootCA.crt
        cat "${SIGNED_CERT}"
        loginfo "Import the Root Cert Below for Trusted Connection"
	cat /srv/.self/rootCA.crt
        loginfo "or transfer using docker cp {container}:${CERT_LOCATION}/stepCA.pem {/local/dir}"
        loginfo "Powershell example command to import downloaded cert into current user root store"
        loginfo "# Import-Certificate -FilePath \"{/dir/download/file}\" -CertStoreLocation cert:\CurrentUser\Root "

}


shutdown_stopapp () {

	stopapp
	exit 0

}

delay_wait () {

        tomorrow_epoc_time=$(date -d "${SP_RTIME} Tomorrow" +%s)
        current_epoc_time=$(date +%s)
        (( sleep_epoch=tomorrow_epoc_time-current_epoc_time ))
        sleep ${sleep_epoch}

}


andcheck () {

        loginfo "waiting to check certificate"

        while true
        do
                #delay_wait
                #if [[ "${SP_RDAY}" == $(date +%A) ]];then
                sleep-control.sh                  
                renew
                #step certificate needs-renewal --expires-in ${TX_WEBPRIV_EXP_CHECK}  ${CERT_LOCATION}/${CERT_NAME}.crt
                retVal=$?
                if [ $retVal -eq 0 ];then                
                        loginfo "certificates refreshed "
                        stopapp
                        startup
                else
                        logerr "ERROR unexpected return code from renewing certificates"
                fi
                #else
                #        loginfo "Not ${SP_RDAY} back to sleep"
                #fi

        done


}


trap shutdown_stopapp TERM INT

if [[ ! -f ${INST_LOCFILE} ]];then

        loginfo "setup SP_APP"
#        sleep-control.sh setup
        initialise_app
        #config_file
        sleep 10
        post_startup_init
        andcheck

else
        
        if check_priv_ca ; then
                loginfo "Renew certificate and startup SP_APP"
                renew
                startup
                andcheck
        else
                logerr "Failure to find local CA - cant renew certificates but starting WEBPRIV and certificates may cause issues "
                startup
                andcheck      
        fi

fi



tail -f /dev/null

