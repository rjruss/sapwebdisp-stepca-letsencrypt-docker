#!/bin/bash

domain="$(hostname -d)"            # your domain
name="$CERTBOT_VALIDATION"                                # name of record to update.
key=$(set +x;shared_get_info.sh LETS CLOUD_KEY;set -x) # key for cloudflare developer API - prod
cloud_domain_id=$(set +x;shared_get_info.sh LETS CLOUD_DOMAIN_ID;set -x) # cloud_domain_id for cloudflare developer API - prod


#echo $CERTBOT_VALIDATION
#echo $CERTBOT_TOKEN
#echo $CERTBOT_REMAINING_CHALLENGES
#echo $CERTBOT_ALL_DOMAINS

ACME_DOM="_acme-challenge.$(echo "$CERTBOT_DOMAIN" |awk -F. '{print $1}')"
#echo $ACME_DOM

headers="Authorization: Bearer $key"

result=$(curl -s -X GET -H "$headers" "https://api.cloudflare.com/client/v4/zones/$cloud_domain_id/dns_records" | jq -r '.result[]|select(.type=="TXT")|select(.content=='"\"$CERTBOT_VALIDATION\""')|.content')


if [ "$result" != "$CERTBOT_VALIDATION" ];
 then
        curl -s --request POST   --url https://api.cloudflare.com/client/v4/zones/$cloud_domain_id/dns_records \
        -H "$headers" \
        -H "Content-Type: application/json" \
        --data '{"type":"TXT","name":'"\"$ACME_DOM\""',"content":'"\"$CERTBOT_VALIDATION\""',"ttl":120}' &>/dev/null
        sleep 120
        exit 0
fi