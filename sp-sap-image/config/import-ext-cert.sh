#!/bin/bash
set -x
CDIR=$(pwd)
SDIR=/tmp/work
mkdir -p ${SDIR}

cd ${SDIR}

import_self_sign () {
	c=$1
	echo "does not have key usage 'Certificate Sign' so guessing with simple check for self signed  : `openssl x509 -noout -subject -in $c`"
	END_DATE=`openssl x509 -enddate -noout -in $c|sed "s/notAfter=//"`
	SDATE=$(date '+%s')
	EDATE=$(date --date="${END_DATE}" '+%s')
	ENDOFCERT=$(( (EDATE - SDATE) / 86400 ))

	ISS=`openssl x509 -subject -noout -in $c|sed "s/subject//"`
	SUB=`openssl x509 -issuer  -noout -in $c|sed "s/issuer//"`
	echo "INFO: Days till cert :${SUB}:  expires is : ${ENDOFCERT}"

	if [[ "$ISS" == "$SUB" ]]
	then
			echo "Appears self signed so import - subject and issuer the same value (but that aint a guarantee that its self signed)"
			sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a $c
			sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -a $c
	else
			echo "INFO:Skipping cert import as :${SUB}: appears not to be not self signed and does not have extension:certification sign"
	fi

}


true | openssl s_client -connect ${SP_TARGET_HOST}:${SP_TARGET_PORT}  -servername   ${SP_TARGET_HOST}  -showcerts 2>/dev/null | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | csplit -k - '/-----BEGIN CERTIFICATE-----/' {*}

find ${SDIR} -name "xx*" -size +1 |while read c
do
        openssl x509 -noout -ext keyUsage -in $c |grep "Certificate Sign" >/dev/null
        retVal=$?
        if [ $retVal -eq 0 ]; then
                echo "importing into client pse: `openssl x509 -noout -subject -in $c`"
                sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a $c
                sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -a $c

        else
                import_self_sign $c
        fi
done

cd ${CDIR}
