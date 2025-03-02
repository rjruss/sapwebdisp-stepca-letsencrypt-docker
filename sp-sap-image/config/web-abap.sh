#!/bin/bash
. shared_logging.sh
SDIR="/srv/usr/sap/webdisp/manage/abap"
>${SDIR}/TEMPCA_ABAP
cd ${SDIR} ||logerr "error changing to ${SDIR}"
#wdisp/system_1 = SID=BB1,  MSHOST=vabap1as1, MSPORT=8101, SRCURL=/sap, SRCSRV=*:4300
##ZABAPwdisp/system_1 = SID=Z_SID,  MSHOST=Z_MSHOST, MSPORT=Z_MSPORT, SRCSRV=*:Z_SRCSRV
#SP_ABAP_SETUP=YES
#SP_ABAP_SID=BB1
#SP_ABAP_HOST_FQDN=vabap1as1.rjruss.org
#SP_ABAP_MS_PORT=8101
#SP_ABAP_HTTP_PORT=
#SP_ABAP_HTTPS_PORT=44300
#ZABAP_SRCSRV=4301
#SP_ZSRCSRV=4300


update_files () {

#wdisp/system_1 = SID=SP_ABAP_SID,  MSHOST=SP_ABAP_HOST_FQDN, MSPORT=SP_ABAP_MS_PORT, SRCSRV=*:ZABAP_SRCSRV
sed -i "s^#wdisp/system_1^wdisp/system_1^;s/SP_ABAP_SID/${SP_ABAP_SID}/;s/SP_ABAP_MSHOST_FQDN/${SP_ABAP_MSHOST_FQDN}/;s/SP_ABAP_MS_PORT/${SP_ABAP_MS_PORT}/;s/ZABAP_SRCSRV/${ZABAP_SRCSRV}/" /srv/usr/sap/webdisp/sapwebdisp.pfl
sed -i "s^#icm/server_port_2^icm/server_port_2^"  /srv/usr/sap/webdisp/sapwebdisp.pfl
sed -i "s/ZABAP_SRCSRV/${ZABAP_SRCSRV}/;s/SP_ABAP_SID/${SP_ABAP_SID}/"  /srv/usr/sap/webdisp/security/data/icm_filter_rules.txt

}

#HTTPS server port
true | openssl s_client -connect "${SP_ABAP_HOST_FQDN}":"${SP_ABAP_HTTPS_PORT}"  -servername   "${SP_ABAP_HOST_FQDN}"  -showcerts 2>/dev/null | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | csplit -f abap -s -k - '/-----BEGIN CERTIFICATE-----/' {*}
#HTTPS message server port
true | openssl s_client -connect "${SP_ABAP_MSHOST_FQDN}":"${SP_ABAP_MS_PORT}"  -servername   "${SP_ABAP_MSHOST_FQDN}"  -showcerts 2>/dev/null | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | csplit -f abapMS -s -k - '/-----BEGIN CERTIFICATE-----/' {*}

find ${SDIR} -name "abap*" -size +1 |while read c
do
        openssl x509 -noout -ext keyUsage -in "$c" |grep "Certificate Sign" >/dev/null
        retVal=$?
        if [ $retVal -eq 0 ]; then
                loginfo "importing into client pse: $(openssl x509 -noout -subject -in $c)"
                sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a $c
        else
                loginfo "does not have key usage 'Certificate Sign' so guess/check if self signed : $(openssl x509 -noout -subject -in "$c")"
                END_DATE=$(openssl x509 -enddate -noout -in "$c"|sed "s/notAfter=//")
                SDATE=$(date '+%s')
                EDATE=$(date --date="${END_DATE}" '+%s')
                ENDOFCERT=$(( (EDATE - SDATE) / 86400 ))
                loginfo "Days till cert Expires ${ENDOFCERT}"

                ISS=$(openssl x509 -subject -noout -in "$c"|sed "s/subject//")
                SUB=$(openssl x509 -issuer  -noout -in "$c"|sed "s/issuer//")

                if [[ "$ISS" == "$SUB" ]]
                then
                                loginfo "Appears self signed so import"
                                sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a "$c"
                else
                                loginfo "Skipping import as :${SUB}: appears not to be not self signed"
                fi

        fi
done

rootdir="/srv/usr/sap/webdisp/rootcerts"
for rfile in "$rootdir"/*; do
if [ -f "$rfile" ]; then
        sapgenpse maintain_pk  -p /srv/usr/sap/webdisp/sec/SAPSSLC.pse -a "${rfile}"
        retVal=$?
        if [ $retVal -eq 0 ]; then
                cat "$rfile" >> ${SDIR}/TEMPCA_ABAP
        fi
fi
done

${SDIR}/self-signed-check.sh 
retVal=$?
if [ $retVal -eq 0 ];then
        loginfo "INFO: Self Signed cert - so update connection details"
        update_files
        exit 0
fi

cat abap* >> ${SDIR}/TEMPCA_ABAP
echo | openssl s_client  -CAfile ${SDIR}/TEMPCA_ABAP  -connect "${SP_ABAP_HOST_FQDN}":"${SP_ABAP_HTTPS_PORT}"  -servername   "${SP_ABAP_HOST_FQDN}" -verify 5 -verify_return_error -quiet
retVal=$?
if [ $retVal -eq 0 ]; then
	loginfo "INFO: successful connection to ${SP_ABAP_SID} over HTTPS on PORT ${SP_ABAP_HTTPS_PORT}"
	update_files
	exit 0
else
	loginfo "ERROR: Failed to validate connection to ${SP_ABAP_SID} over HTTPS on PORT ${SP_ABAP_HTTPS_PORT}"
	exit 1
fi


cd ~


