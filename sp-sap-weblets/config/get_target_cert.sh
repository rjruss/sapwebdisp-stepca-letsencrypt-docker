#!/bin/bash
#set -x

SCR="/srv/usr/sap/webdisp/cloudflare"
WRK="/srv/usr/sap/webdisp/cloudflare/wrk"
EML=${SP_EMAIL}
cd ${SCR} || logerr "error changing directory to directory ${SDIR}"

mkdir -p ${WRK}

import_self_sign () {
        c=$1
        loginfo "INFO: cert does not have key usage 'Certificate Sign' so guess/check if self signed : $(openssl x509 -noout -subject -in $c)"
        END_DATE=$(openssl x509 -enddate -noout -in $c|sed "s/notAfter=//")
        SDATE=$(date '+%s')
        EDATE=$(date --date="${END_DATE}" '+%s')
        ENDOFCERT=$(( (EDATE - SDATE) / 86400 ))

        ISS=$(openssl x509 -subject -noout -in $c|sed "s/subject//")
        SUB=$(openssl x509 -issuer  -noout -in $c|sed "s/issuer//")
        loginfo "INFO: Days till cert :${SUB}:  expires is : ${ENDOFCERT}"

        if [[ "$ISS" == "$SUB" ]]
        then
                        loginfo "INFO: cert appears to be self signed so import"
                        sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a $c
                        sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -a $c

        else
                        loginfo "INFO:Skipping cert import as :${SUB}: appears not to be not self signed and does not have extension:certification sign"

        fi
}


true | openssl s_client -connect "${SP_TARGET_HOST}:${SP_TARGET_PORT}"  -servername  "${SP_TARGET_HOST}" -showcerts 2>/dev/null | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | csplit -s -k - '/-----BEGIN CERTIFICATE-----/' {*}

find ${SCR} -name "xx*" -size +1 |while read c
do
        echo $c
        openssl x509 -noout -ext keyUsage -in $c |grep "Certificate Sign" >/dev/null
        retVal=$?
        echo "return ${retVal} : $(openssl x509 -noout -subject -in $c)"
        if [ $retVal -eq 0 ]; then
                loginfo "INFO: importing into client pse: $(openssl x509 -noout -subject -in $c)"
                sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a $c
                #cat $c >> ${WRK}/rootCAonly
        else
		import_self_sign $c
        fi

done

openssl verify -CAfile  ${SCR}/isrgrootx1.pem -untrusted ${SCR}/0000_chain.pem ${SCR}/0000_cert.pem

cat xx* >> ${WRK}/TEMPCA
true | openssl s_client  -CAfile ${WRK}/TEMPCA -partial_chain  -connect "${SP_TARGET_HOST}:${SP_TARGET_PORT}" -servername   "${SP_TARGET_HOST}" -verify 5 -verify_return_error &>/dev/null
retVal=$?
        if [ $retVal -eq 0 ]; then
                loginfo "INFO: importing into client pse: $(openssl x509 -noout -subject -in $c)"
		return 0
                #cat $c >> ${WRK}/rootCAonly
        else
		logerr "ERROR: Cant validate ${SP_TARGET_HOST} certificate chain"
		return 1
        fi



cd ~
