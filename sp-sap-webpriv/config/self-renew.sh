#!/bin/bash
set -x
DT=$(date +"%d%m%Y")
SDIR="/srv/.self"
SP_RENEW_VALID_DAYS=$( cat /srv/usr/sap/webdisp/manage/control_cert_renew_length )
cd "${SDIR}"
#CAFILE="${SDIR}/defaultvals.txt"
LOGF="${SDIR}/renewlog.txt"
#check in seconds - e.g set var DAYS to...
#DAYS=1 ;one day 86400
#DAYS=5 ;five days 432000
DAYS=$(cat /srv/usr/sap/webdisp/manage/control_cert_check_days)
#DAYS=${SP_RCOUNT}

if [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  loginfo "The system is currently set to check for certificate expiration $DAYS before it expires."
else
  logwarn "Variable DAYS = ${DAYS} is not a valid integer -setting default 7 days."
  DAYS=7
fi

>${SDIR}/importCRTrenew.crt
sleep 5

renew () {
#Just generate new CSR
sapgenpse get_pse -p ${SECUDIR}/DOCKERSSL.pse  -r ${CSR_LOCATE}  -onlyreq -j

#setup file discriptor option for pass* options
exec 4<&-
exec 4<<<"$(set +x;shared_get_info.sh PRIV CA_PW;set -x)"

#SIGN the web disp CSR
openssl x509 -req -in $CSR_LOCATE -CA ${SDIR}/rootCA.crt -CAkey ${SDIR}/rootCA.key  -passin fd:4 -CAcreateserial -copy_extensions copyall -out ${SDIR}/webRENEW.crt -days $SP_RENEW_VALID_DAYS -sha256 || exec 4<&-
#remove file discriptor
exec 4<&-

#Combine Root CA and signed CR Certs for import
cat ${SDIR}/rootCA.crt ${SDIR}/webRENEW.crt >> ${SDIR}/importCRTrenew.crt
sapgenpse import_own_cert  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -c ${SDIR}/importCRTrenew.crt -v
return $?
}

sapgenpse export_own_cert -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -o owncert.pem -v


(( SEC=(24*60*60)*${DAYS} ))

if openssl x509 -checkend $SEC -noout -in owncert.pem
then
  loginfo "CHECK ON:${DT}:Certificate is good" |tee -a ${LOGF}
  return 0
else
  logwarn "CHECK ON:${DT}:Certificate has expired or will do so within ${DAYS} days. (or is invalid/not found)" |tee -a ${LOGF}
  renew
  return $?
fi
sapgenpse export_own_cert -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -o owncertCOMP.pem -v
