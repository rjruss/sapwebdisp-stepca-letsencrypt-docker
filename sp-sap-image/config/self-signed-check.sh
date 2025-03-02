#!/bin/bash
#check for  self-signed certificate
SDIR="/srv/usr/sap/webdisp/manage/abap"


retVal=`echo| openssl s_client -quiet -CAfile ${SDIR}/TEMPCA_ABAP  -connect ${SP_ABAP_HOST_FQDN}:${SP_ABAP_HTTPS_PORT}  -servername   ${SP_ABAP_HOST_FQDN} -verify 5 -verify_return_error 2>&1 |grep "verify error:" |awk -F: '{print $3}'`

if [[ "${retVal}" == "self-signed certificate" ]]
then
        exit 0
else
        exit 1
fi