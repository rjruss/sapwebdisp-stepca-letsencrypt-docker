#!/bin/bash
. shared_logging.sh

check_cert_location="/srv/usr/sap/webdisp/manage/owncert-check.pem"
logf="/srv/usr/sap/webdisp/manage/checkcert-log.txt"
days=$(cat /srv/usr/sap/webdisp/manage/control_cert_check_days)

rm -f ${check_cert_location}

if [[ "$days" =~ ^[0-9]+$ ]]; then
  loginfo "The system is currently set to check for certificate expiration $days before it expires."
else
  logwarn "Variable days = ${days} is not a valid integer -setting default 7 days."
  days=7
fi

sapgenpse export_own_cert -p /srv/usr/sap/webdisp/sec/DOCKERSSL.pse -o  ${check_cert_location}  &>/dev/null

(( sec=(24*60*60)*${days} ))
expire_date_of_cert=$(openssl x509 -enddate -noout -in ${check_cert_location})

if openssl x509 -checkend $sec -noout -in  ${check_cert_location} &>/dev/null
then
  loginfo "Certificate is good and will expire on ${expire_date_of_cert}" |tee -a ${logf}
  exit 0
else
  logwarn "Certificate has expired or will do so within ${days} days. Expire date is ${expire_date_of_cert} (or is invalid/not found)" |tee -a ${logf}
  exit 1
fi
