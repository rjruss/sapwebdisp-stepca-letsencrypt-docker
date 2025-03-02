#!/bin/bash
set -x
DT=$(date +"%d%m%Y")
SDIR="/srv/usr/sap/webdisp/cloudflare"
cd ${SDIR} || logerr "error changing directory to directory ${SDIR}"
LOGF=${SDIR}/renewlog.txt
#check in seconds - e.g set var DAYS to...
#DAYS=1 ;one day 86400
#DAYS=5 ;five days 432000
DAYS=${SP_RCOUNT}


renew () {
#Just generate new CSR
sapgenpse get_pse -p "${SECUDIR}"/DOCKERSSL.pse  -r "${CSR_LOCATE}"  -onlyreq -j
#SIGN the web disp CSR
. get_lets_cert.sh
return $?
}

sapgenpse export_own_cert -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -o owncert.pem -v


(( SEC=(24*60*60)*${DAYS} ))

if openssl x509 -checkend $SEC -noout -in owncert.pem
then
  echo "INFO: CHECK ON:${DT}:Certificate is good" |tee -a ${LOGF}
  return 0
else
  echo "INFO: CHECK ON:${DT}:Certificate has expired or will do so within ${DAYS} days. (or is invalid/not found)" |tee -a ${LOGF}
  renew
  return $?
fi