#!/bin/bash
#set -x
. .env
. ./sp-sap-image/config/shared/shared_logging.sh
CDIR=$(pwd)
SDIR=$(mktemp -d)
>${SDIR}/TEMPCA_ABAP
cd "${SDIR}" || exit


return_code () {
        loginfo "${retVal} ------ return code"
        if [ ${1} -eq 0 ]; then
                loginfo "INFO: successful connection to ${SP_ABAP_SID} ${2} over HTTPS on PORT ${3}"
        else
                logerr "Failed to validate connection to ${SP_ABAP_SID} ${2} over HTTPS on PORT ${3}"
        fi

}

s_client_connection_check () {
for i in 1 5; do
        loginfo "---${1}:${2} Verify certificate chain at level ${i}"
        true | openssl s_client  -CAfile "${SDIR}"/TEMPCA_ABAP  -connect "${1}":"${2}"  -servername "${1}" -verify "${i}" -verify_return_error -quiet &>/dev/null
        retVal=$?
        return_code "${retVal}" "${1}" "${2}"
        loginfo "---${1}:${2} end of level ${i}---"
done
}

curl_connection_check () {

        loginfo "---${1}:${2} Verify HTTPS connection"
        curl  --cacert "${SDIR}"/TEMPCA_ABAP  https://"${1}":"${2}"  &>/dev/null
        retVal=$?
        return_code "${retVal}" "${1}" "${2}"
        loginfo "---${1}:${2} end of HTTPS connection check ---"

}

if [[ "${SP_ABAP_HOST_FQDN}" == "a4h" ]];then
        #docker inspect a4h | jq -r '.[].NetworkSettings.Networks | to_entries[] | .value.DNSNames|@csv'
        SP_ABAP_HOST_FQDN="vhcala4hci.${DOMAIN}"
        loginfo "status of a4h"
        docker exec a4h su - a4hadm -c "sapcontrol -nr 00 -function GetSystemInstanceList" |grep vhcala4hci

fi

#HTTPS server port
true | openssl s_client -connect "${SP_ABAP_HOST_FQDN}":"${SP_ABAP_HTTPS_PORT}"  -servername   "${SP_ABAP_HOST_FQDN}"  -showcerts 2>/dev/null | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | csplit -f abap -s -k - '/-----BEGIN CERTIFICATE-----/' {*}
#HTTPS message server port
true | openssl s_client -connect "${SP_ABAP_HOST_FQDN}":"${SP_ABAP_MS_PORT}"  -servername   "${SP_ABAP_HOST_FQDN}"  -showcerts 2>/dev/null | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | csplit -f abapMS -s -k - '/-----BEGIN CERTIFICATE-----/' {*}

find ${SDIR} -name "abap*" -size +1 |while read c
do
        openssl x509 -noout -ext keyUsage -in $c |grep "Certificate Sign" >/dev/null
        retVal=$?
        if [ $retVal -eq 0 ]; then
                loginfo "found signing certifcate: $(openssl x509 -noout -subject -in $c)"
        else
                loginfo "does not have key usage 'Certificate Sign' so guess/check if self signed : $(openssl x509 -noout -subject -in $c)"
                END_DATE=$(openssl x509 -enddate -noout -in $c|sed "s/notAfter=//")
                SDATE=$(date '+%s')
                EDATE=$(date --date="${END_DATE}" '+%s')
                ENDOFCERT=$(( (EDATE - SDATE) / 86400 ))
                loginfo "Days till cert Expires ${ENDOFCERT}"

                ISS=$(openssl x509 -subject -noout -in $c|sed "s/subject//")
                SUB=$(openssl x509 -issuer  -noout -in $c|sed "s/issuer//")

                if [[ "$ISS" == "$SUB" ]]
                then
                                loginfo "Appears self signed so import ${ISS} so this will be used"
                else
                                loginfo "Skipping import as :${SUB}: appears not to be not self signed"
                fi

        fi
done

rootdir="${CDIR}/sp-sap-image/rootcerts"
for rfile in "$rootdir"/*; do
if [ -f "$rfile" ]; then
                cat $rfile >> ${SDIR}/TEMPCA_ABAP
fi
done


retVal=$(echo| openssl s_client -quiet -CAfile ${SDIR}/TEMPCA_ABAP  -connect "${SP_ABAP_HOST_FQDN}":"${SP_ABAP_HTTPS_PORT}"  -servername   "${SP_ABAP_HOST_FQDN}" -verify 5 -verify_return_error 2>&1 |grep "verify error:" |awk -F: '{print $3}')
if [[ "${retVal}" == "self-signed certificate" ]]
then
        loginfo "ABAP server appears to use self-signed certificate" 
fi

cat abap* >> "${SDIR}"/TEMPCA_ABAP

s_client_connection_check "${SP_ABAP_HOST_FQDN}" "${SP_ABAP_HTTPS_PORT}" 
curl_connection_check "${SP_ABAP_HOST_FQDN}" "${SP_ABAP_MS_PORT}" 
curl_connection_check "${SP_ABAP_MSHOST_FQDN}" "${SP_ABAP_MS_PORT}" 
#echo | openssl s_client  -CAfile "${SDIR}"/TEMPCA_ABAP  -connect "${SP_ABAP_HOST_FQDN}":"${SP_ABAP_HTTPS_PORT}"  -servername   "${SP_ABAP_HOST_FQDN}" -verify 5 -verify_return_error -quiet &>/dev/null
#retVal=$?
#if [ $retVal -eq 0 ]; then
#	loginfo "INFO: successful connection to ${SP_ABAP_SID} over HTTPS on PORT ${SP_ABAP_HTTPS_PORT}"
#else
#	logerr "Failed to validate connection to ${SP_ABAP_SID} over HTTPS on PORT ${SP_ABAP_HTTPS_PORT}"
#fi



cd ~ || loginfo "should never display"

echo "${SDIR}"
find  "${SDIR}" -ls