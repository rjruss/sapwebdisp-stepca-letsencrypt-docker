#!/bin/bash


. .env

imp_power () {
echo "\$B64=\"$1\" "
echo "\$B64 | Out-File .\\${2}"
echo "Import-Certificate  -FilePath .\\${2}  -CertStoreLocation cert:\CurrentUser\Root"

}


while read c
do
	echo " ## $c"
if [[ "$c" == *"step"* ]]; then
    echo " ## STEP powershell to trust certificate - added as a trusted root so use it on that understanding"
    CERT=$(docker exec  $c cat /srv/.self/certs/stepCA.pem)
    imp_power "$CERT" WEBSTEP.crt
    echo
fi
if [[ "$c" == *"priv"* ]]; then
    echo " ## PRIVATE CA powershell to trust certificate - added as a trusted root so use it on that understanding"
    CERT=$(docker exec  $c cat /srv/.self/rootCA.crt)
    imp_power "$CERT" WEBPRIV.crt
    echo
fi


done < <(yq  '.services.*.container_name' *extr*.yml | sed '/^---$/d' |grep web)


while read i
do
	V=$(echo $i|awk -F\$ '{print $2}'|sed 's/[\{\}\.]//g')
	P="${V}_PORT"
    echo "-${V}s"
    ZA="$(echo $V|sed 's/_HOST//')_ZABAP_SRCSRV"
    echo "Web dispatcher link for $SP_TARGET_HOST" 
	echo "https://${!V}.$DOMAIN:${!P}"
    echo "Web dispatcher link to $SP_ABAP_HOST_FQDN"
    echo "https://${!V}.$DOMAIN:${!ZA}"
    echo "---"
done < <(grep '_HOST\}.${D'  *yml )
