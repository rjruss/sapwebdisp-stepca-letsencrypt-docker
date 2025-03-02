#!/bin/bash

set -x
. shared_logging.sh
###############################
## ACtion - _CHANGE_TO_REQUIRED_APP_CERT_DUR_VARIABLE to the required Variable
## ACtion - Update INST_LOCFILE & CERT_LOCATION
#################################
HOST_FQDN=$(hostname -f)

INST_LOCFILE="${SECUDIR}/DOCKERSSL.pse"
#SP_CONTAINER_NAME
CERT_LOCATION="/srv/.self/certs"
CERT_NAME="webstep"

# CSR_LOCATE SIGNED_CERT

check_step_ca () {

        #check_step_ca ${number_of_loops} ${sleep duration}
        for (( i=1; i<=${1}; i++ )); do
                curl -sk  "${SP_STEP_HOST}/roots.pem" -o "${CERT_LOCATION}/stepCA.pem"
                retVal=$?
                if [[ $retVal -eq 0 ]];then
                       # (( stepca_cdur=$(step ca provisioner list --ca-url=${SP_STEP_HOST} --root=${CERT_LOCATION}/stepCA.pem |jq -r '.[0].claims.maxTLSCertDuration | split("h")[0]') ))
                        (( stepca_cdur=$(step ca provisioner list --ca-url="${SP_STEP_HOST}" --root=${CERT_LOCATION}/stepCA.pem |jq -r --arg  pname "$SP_PROV_NAME" '.[]|select(.name == $pname )|.claims.maxTLSCertDuration| split("h")[0]' ) ))
                        (( app_cdur=$(echo "$SP_WEBSTEP_CERT_DUR" |sed "s/h//") ))
                        if [[ "$app_cdur" -le "$stepca_cdur" ]]; then
                                return 0
                                else
                                logwarn "Step is available but the max certificate expiry is not set correctly, this app script wants $app_cdur duration. Waiting for step-ca as its currently $stepca_cdur: attempt $i / ${1}"
                        fi
                fi
                sleep ${2}
        done

        return 1

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
        (( days=$(echo ${SP_WEBSTEP_CERT_DUR//h/})/24))
        echo "${days}" > /srv/usr/sap/webdisp/manage/control_cert_renew_length
    fi
}


initialise_app () {

	loginfo "initial setup of application"
        setup_files
        FP=$(step certificate fingerprint ${CERT_LOCATION}/stepCA.pem)
        step ca bootstrap --ca-url ${SP_STEP_HOST} --fingerprint ${FP}
	#app server certificate
	#step ca certificate ${SP_CONTAINER_NAME} ${CERT_LOCATION}/${CERT_NAME}.crt ${CERT_LOCATION}/${CERT_NAME}.key  --not-after ${SP_WEBSTEP_CERT_DUR} --san ${SP_CONTAINER_NAME} --san $HOST_FQDN  --provisioner-password-file  <(set +x;echo -n `shared_get_info.sh STEP PW`;set -x)


}

sign_csr () {


        days=$(cat /srv/usr/sap/webdisp/manage/control_cert_renew_length )
        hours="$((days*24))h"
	#step ca sign  --not-after "${SP_WEBSTEP_CERT_DUR}" "${CSR_LOCATE}" "${SIGNED_CERT}"  --provisioner-password-file  <(set +x;echo -n $(shared_get_info.sh STEP PW);set -x)
        step ca sign  --provisioner="$SP_PROV_NAME"  --not-after "${hours}" "${CSR_LOCATE}" "${SIGNED_CERT}"  --provisioner-password-file  <(set +x;echo -n $(shared_get_info.sh STEP PW);set -x)
}

import_pse_roots () {

	sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a ${CERT_LOCATION}/stepCA.pem 
	sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLS.pse -a ${CERT_LOCATION}/stepCA.pem
	sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -a ${CERT_LOCATION}/stepCA.pem

}


import_pse_certs () {
	>${CERT_LOCATION}/signed-cert-chain.pem
	cat ${CERT_LOCATION}/stepCA.pem "${SIGNED_CERT}" >> ${CERT_LOCATION}/signed-cert-chain.pem
	sapgenpse import_own_cert  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -c ${CERT_LOCATION}/signed-cert-chain.pem
}

renew () {

        loginfo "checking certificate for renewal"

        #step certificate verify "${SIGNED_CERT}"  --roots "${STEPPATH}/certs/root_ca.crt"  --host="${HOST_FQDN}"
        check_cert.sh
        retVal=$?
        if [ $retVal -eq 0 ];then
                loginfo "certificate ${CERT_NAME} not expiring"
		#step ca renew -f ${CERT_LOCATION}/${CERT_NAME}.crt ${CERT_LOCATION}/${CERT_NAME}.key
                #rm -f "${CSR_LOCATE}"
                #rm -f "${SIGNED_CERT}"
		#sapgenpse get_pse -p ${SECUDIR}/DOCKERSSL.pse  -r ${CSR_LOCATE}  -onlyreq -j
		#sign_csr
		#import_pse_certs
        else
                #extra check with step
                #step certificate verify "${SIGNED_CERT}"  --roots "${STEPPATH}/certs/root_ca.crt"  --host="${HOST_FQDN}"
                #retVal=$?
                #if [ $retVal -eq 0 ];then
                        logwarn "${SIGNED_CERT} certificate expired or other error "
                        #loginfo "recreate ${SIGNED_CERT} certificate, creating csr from scratch"
                        rm -f "${CSR_LOCATE}"
                        rm -f "${SIGNED_CERT}"
                        #/srv/usr/sap/webdisp/sapgenpse gen_pse -p "${SECUDIR}/DOCKERSSL.pse" -x '' -r "${CSR_LOCATE}" -k GN-dNSName:${HOST_FQDN} 'CN='"${HOST_FQDN}"', DNS='"${HOST_FQDN}"', C=GB'
                        sapgenpse get_pse -p ${SECUDIR}/DOCKERSSL.pse  -r ${CSR_LOCATE}  -onlyreq -j
                        sign_csr
                        import_pse_certs
                #fi
        #           step ca certificate ${SP_CONTAINER_NAME} ${CERT_LOCATION}/${CERT_NAME}.crt ${CERT_LOCATION}/${CERT_NAME}.key  --not-after ${SP_WEBSTEP_CERT_DUR} --san ${SP_CONTAINER_NAME} --san $HOST_FQDN  --provisioner-password-file  <(set +x;echo -n `shared_get_info.sh STEP PW`;set -x)
        fi


}

startup () {

	loginfo "startup"
        /srv/usr/sap/webdisp/sapwebdisp pf=/srv/usr/sap/webdisp/sapwebdisp.pfl &


}

stopapp () {

	loginfo "stopping "
        pkill -P $$

}

config_file () {

	loginfo "config_file"
        sed -i "s/ZHOST_FQDN/${HOST_FQDN}/;s/ZWEBADM_PORT/${ZWEBADM_PORT}/" /srv/usr/sap/webdisp/security/data/icm_filter_rules.txt
        sed -i "s/ZSP_TARGET_HOST/${SP_TARGET_HOST}/;s/SP_ZSRCSRV/${SP_ZSRCSRV}/" /srv/usr/sap/webdisp/security/data/icm_filter_rules.txt
        sed -i "s/ZSP_TARGET_HOST:ZSP_TARGET_PORT/${SP_TARGET_HOST}:${SP_TARGET_PORT}/" /srv/usr/sap/webdisp/sapwebdisp.pfl
        sed -i "s/SP_ZSRCSRV/${SP_ZSRCSRV}/;s/ZWEBADM_PORT/${ZWEBADM_PORT}/" /srv/usr/sap/webdisp/sapwebdisp.pfl
	sed -i "s/ZWEB_HOST_PORT/${WEBSTEP_HOST_PORT}/g" /srv/usr/sap/webdisp/sapwebdisp.pfl
        /srv/usr/sap/webdisp/sapgenpse gen_pse -p "${SECUDIR}/DOCKERSSL.pse" -x '' -r "${CSR_LOCATE}" -k GN-dNSName:${HOST_FQDN} 'CN='"${HOST_FQDN}"', DNS='"${HOST_FQDN}"', C=GB'
        #"/srv/usr/sap/webdisp/sapgenpse seclogin -p ${SECUDIR}/DOCKERSSL.pse -x ${PIN} -O dwdadm"
        sleep 5
        ls -l ${SECUDIR}/DOCKERSSL.pse
        /srv/usr/sap/webdisp/sapwebdisp pf=/srv/usr/sap/webdisp/sapwebdisp.pfl &
        loginfo "sleep 10"
        sleep 10
	stopapp
	sign_csr
	import_pse_roots
	import_pse_certs
	. import-ext-cert.sh
        #/srv/usr/sap/webdisp/manage/manage-sign.sh
        if [ "$SP_ABAP_SETUP" == "YES" ]
        then
                /srv/usr/sap/webdisp/manage/web-abap.sh
        fi
        sleep 2



}


post_startup_init () {

	loginfo "post start initialisation actions"
        /srv/usr/sap/webdisp/manage/setwebadm.sh &
        sleep 5
        ## Import trusted own root cert
        #trust anchor /srv/usr/sap/webdisp/manage/rootCA.crt
        cat "${SIGNED_CERT}"
        loginfo "Import the Root Cert Below for Trusted Connection"
	cat  "${STEPPATH}/root_ca.crt"
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
        #loginfo "sleep every day until the chosen day to check the cert"
                while true
                do
                        sleep-control.sh

                        renew
                        loginfo "restarting after certificate refresh process "
                        stopapp
                        startup

                done

}


trap shutdown_stopapp TERM INT

if [[ ! -f ${INST_LOCFILE} ]];then
        if check_step_ca 3 20; then
                loginfo "setup SP_APP"
                initialise_app
                config_file
                startup
                sleep 25
                post_startup_init
                andcheck
        else
                logerr "Exiting setup as step ca cant be contacted"
        fi


else
        
        if check_step_ca 3 20; then
                loginfo "Renew certificate and startup SP_APP"
                renew
                startup
                andcheck
        else
                logerr "Failure to connect to step-ca - cant renew certificates but starting WEBSTEP and certificates may cause issues "
                startup
                andcheck      
        fi

fi



tail -f /dev/null

