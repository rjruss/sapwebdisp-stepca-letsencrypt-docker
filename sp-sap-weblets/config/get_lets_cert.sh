#!/bin/bash
set -x
#status page lets encrypt
#https://letsencrypt.status.io/

SCR="/srv/usr/sap/webdisp/cloudflare"
WRK="/srv/usr/sap/webdisp/cloudflare/wrk"

cd ${SCR} || logerr "error changing directory to directory ${SDIR}"

mkdir -p ${WRK}


curl -s https://letsencrypt.org/certs/isrgrootx1.pem -o ${SCR}/isrgrootx1.pem

certbot certonly --manual --csr "${CSR_LOCATE}"   --preferred-challenges=dns --manual-auth-hook ${SCR}/upd_cloudflare.sh --manual-cleanup-hook ${SCR}/del_cloudflare.sh --config-dir=${WRK}  --work-dir=${WRK} --logs-dir=${WRK}  --non-interactive --agree-tos -m "${SP_EMAIL}" 
retVal=$?
if [ $retVal -eq 0 ]; then
	loginfo "INFO: Successful call to lets encrypt"
	cat ${SCR}/isrgrootx1.pem ${SCR}/0000_chain.pem ${SCR}/0000_cert.pem > ${SCR}/importCRT.crt
	openssl verify -CAfile  ${SCR}/isrgrootx1.pem -untrusted ${SCR}/0000_chain.pem ${SCR}/0000_cert.pem 
	sapgenpse import_own_cert  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -c ${SCR}/importCRT.crt
	sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a ${SCR}/isrgrootx1.pem
	sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLS.pse -a ${SCR}/isrgrootx1.pem
	sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -a ${SCR}/isrgrootx1.pem
	return 0
else
	logerr "ERROR: $retVal returned from certbot process"
	return 1
fi
