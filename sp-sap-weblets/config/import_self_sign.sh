#!/bin/bash
#set -x

SCR="/srv/usr/sap/webdisp/cloudflare"
WRK="/srv/usr/sap/webdisp/cloudflare/wrk"
EML="rob.roosky@yahoo.com"

cd ${SCR} || logerr "error changing directory to directory ${SDIR}"

mkdir -p ${WRK}

c=$1
echo "INFO: cert does not have key usage 'Certificate Sign' so guess/check if self signed : $(openssl x509 -noout -subject -in $c)"
END_DATE=$(openssl x509 -enddate -noout -in $c|sed "s/notAfter=//")
SDATE=$(date '+%s')
EDATE=$(date --date="${END_DATE}" '+%s')
ENDOFCERT=$(( (EDATE - SDATE) / 86400 ))

ISS=$(openssl x509 -subject -noout -in $c|sed "s/subject//")
SUB=$(openssl x509 -issuer  -noout -in $c|sed "s/issuer//")
echo "INFO: Days till cert :${SUB}:  expires is : ${ENDOFCERT}"

if [[ "$ISS" == "$SUB" ]]
then
	echo "INFO: cert appears to be self signed so import"
	sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a $c
	sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -a $c
							 
else
	echo "INFO:Skipping cert import as :${SUB}: appears not to be not self signed and does not have extension:certification sign"
						
fi