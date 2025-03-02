#!/bin/bash
domain="$(hostname -d)"            # your domain
name="$CERTBOT_VALIDATION"                                # name of record to update.
key=$(set +x;shared_get_info.sh LETS CLOUD_KEY;set -x) # key for cloudflare developer API - prod
cloud_domain_id=$(set +x;shared_get_info.sh LETS CLOUD_DOMAIN_ID;set -x) # cloud_domain_id for cloudflare developer API - prod

#echo $CERTBOT_DOMAIN
#echo $CERTBOT_VALIDATION
#echo $CERTBOT_TOKEN
#echo $CERTBOT_REMAINING_CHALLENGES
#echo $CERTBOT_ALL_DOMAINS


headers="Authorization: Bearer $key"

result=$(curl -s -X GET -H "$headers" "https://api.cloudflare.com/client/v4/zones/$cloud_domain_id/dns_records" | jq -r '.result[]|select(.type=="TXT")|select(.content=='"\"$CERTBOT_VALIDATION\""')|.id')


if [ "$result" != "" ];
 then
        curl -s -X DELETE --output /dev/null "https://api.cloudflare.com/client/v4/zones/$cloud_domain_id/dns_records/$result" \
                -H "$headers" \
                -H "Content-Type: application/json"
        retVal=$?
        if [ $retVal -eq 0 ];then
                exit 0
        else
                exit 1
        fi
else
      echo "No action taken as the TXT record ID not found in DNS - check manually" >> dns_delete_error.log
        exit 1
fi