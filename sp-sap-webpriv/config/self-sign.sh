#!/bin/bash

SDIR="/srv/.self"
SP_RENEW_VALID_DAYS=$( cat /srv/usr/sap/webdisp/manage/control_cert_renew_length )

loginfo " CN ------------------ : ${SP_ROOTCN}"
cd ${SDIR} || logerr "directory ${SDIR} does not exist"
cat <<EOF > ${SDIR}/defaultvals.txt
[ ca ]
default_ca	= CA_default		# The default ca section
[ req ]
default_bits           = 2048
default_keyfile        = keyfile.pem
default_md             = sha256
distinguished_name     = req_distinguished_name
prompt                 = no
x509_extensions	       = v3_ca
[ req_distinguished_name ]
C                      = $SP_ROOTC 
#ST                     = Some state
#L                      = Somewhere out there
#O                      = Mine
#OU                     = Testing
CN                     = $SP_ROOTCN
emailAddress           = $SP_EMAIL
[ v3_ca ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = CA:true
keyUsage = cRLSign, keyCertSign
EOF

import_self_sign () {
	c=$1
	loginfo "does not have key usage 'Certificate Sign' so guessing with simple check for self signed  : $(openssl x509 -noout -subject -in $c)"
	END_DATE=$(openssl x509 -enddate -noout -in $c|sed "s/notAfter=//")
	SDATE=$(date '+%s')
	EDATE=$(date --date="${END_DATE}" '+%s')
	ENDOFCERT=$(( (EDATE - SDATE) / 86400 ))

	ISS=$(openssl x509 -subject -noout -in $c|sed "s/subject//")
	SUB=$(openssl x509 -issuer  -noout -in $c|sed "s/issuer//")
	loginfo "INFO: Days till cert :${SUB}:  expires is : ${ENDOFCERT}"

	if [[ "$ISS" == "$SUB" ]]
	then
			loginfo "Appears self signed so import - subject and issuer the same value (but that aint a guarantee that its self signed)"
			sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a $c
			sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -a $c
	else
			logwarn "INFO:Skipping cert import as :${SUB}: appears not to be not self signed and does not have extension:certification sign"
	fi

}

#setup file discriptor option for pass* options
exec 4<&-
exec 4<<<"$(set +x;shared_get_info.sh PRIV CA_PW;set -x)"

#Create key
openssl genrsa  -passout fd:4 -aes256 -out ${SDIR}/rootCA.key 4096 || exec 4<&-

exec 4<<<"$(set +x;shared_get_info.sh PRIV CA_PW;set -x)"
#Create Root CA cert
openssl req -x509 -new -key ${SDIR}/rootCA.key -passin fd:4 -sha256 -days "$SP_ROOTCA_VALID" -out ${SDIR}/rootCA.crt -config ${SDIR}/defaultvals.txt || exec 4<&-

exec 4<<<"$(set +x;shared_get_info.sh PRIV CA_PW;set -x)"
#SIGN the web disp CSR
openssl x509 -req -in "$CSR_LOCATE" -CA "${SDIR}/rootCA.crt" -CAkey "${SDIR}/rootCA.key"  -passin fd:4 -CAcreateserial -copy_extensions copyall -out "${SIGNED_CERT}" -days "$SP_RENEW_VALID_DAYS" -sha256 || exec 4<&-

#remove file discriptor
exec 4<&-

#Combine Root CA and signed CR Certs for import
cat ${SDIR}/rootCA.crt "${SIGNED_CERT}" >> ${SDIR}/importCRT.crt


sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a ${SDIR}/rootCA.crt
sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLS.pse -a ${SDIR}/rootCA.crt
sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -a ${SDIR}/rootCA.crt
sapgenpse import_own_cert  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -c ${SDIR}/importCRT.crt

true | openssl s_client -connect "${SP_TARGET_HOST}:${SP_TARGET_PORT}"  -servername   "${SP_TARGET_HOST}"  -showcerts 2>/dev/null | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | csplit -k - '/-----BEGIN CERTIFICATE-----/' {*}

find ${SDIR} -name "xx*" -size +1 |while read c
do
	openssl x509 -noout -ext keyUsage -in $c |grep "Certificate Sign" >/dev/null
	retVal=$?
	if [ $retVal -eq 0 ]; then
		loginfo "importing into client pse: $(openssl x509 -noout -subject -in $c)"
		sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a $c 
	else
		import_self_sign $c
	fi
done

rootdir="/srv/usr/sap/webdisp/rootcerts"
for rfile in "$rootdir"/*; do
if [ -f "$rfile" ]; then
        sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a ${rfile}
        retVal=$?
        if [ $retVal -eq 0 ]; then
                cat $rfile >> ${SDIR}/TEMPCA
        fi
fi
done

cat xx* >> ${SDIR}/TEMPCA
true | openssl s_client  -CAfile "${SDIR}/TEMPCA" -partial_chain  -connect "${SP_TARGET_HOST}:${SP_TARGET_PORT}"  -servername   "${SP_TARGET_HOST}" -verify 5 -verify_return_error &>/dev/null
retVal=$?
        if [ $retVal -eq 0 ]; then
                loginfo "INFO: success checking connection to $(openssl x509 -noout -subject -in ${SDIR}/TEMPCA)"
                return 0
                #cat $c >> ${SDIR}/rootCAonly
        else
				logerr "ERROR: Cant validate ${SP_TARGET_HOST} certificate chain"
                return 1
        fi




cd ~