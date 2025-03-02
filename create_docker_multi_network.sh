#!/bin/bash

if ! command -v yq &> /dev/null ;then
    echo "yq could not be found"
    exit 1
fi
. .env
DOCKER_SUFFIX="extracted-compose.yml"
DOCKER_NETWORK_SUFFIX="net1"

SN=""
while read DOCKER_FILE ;do
	echo "processing ${DOCKER_FILE}"
	while read i
	do
	CHECKNET=$(docker network inspect ${i} 2>/dev/null|jq -r '.[]|.Options.device')
	if [[ "${CHECKNET}" == "" ]] ;then
		echo "create docker network"
		docker network create "${i}"
		SN=$(docker network inspect ${i} |jq -r '.[].IPAM.Config[]|.Subnet')
	else
		echo "  warning network $i exists already, no action taken"
	fi
	done < <(yq '.networks | keys | .[]' "${DOCKER_FILE}" |grep "${DOCKER_NETWORK_SUFFIX}")
done < <(ls *${DOCKER_SUFFIX})
echo

if [[ "${SN}" != "" ]] ; then
	echo "processing physical nics"
	for iface in /sys/class/net/*; do
		iface_name=$(basename "$iface")	
	  	if [ -e "$iface"/device ] && ethtool "$iface_name" | grep -q "Supported ports"; then
	    	echo "$iface"
	    	SN=${SN}",$(ip -o -f inet addr show "$iface_name" | awk '{print $4}')"
	  	fi
	done
echo
echo "adding ${SN} as trusted subnet value for postgres config"
if ! grep "^SP_ALLOWED_SUBNET" .env;then
        echo "SP_ALLOWED_SUBNET=${SN}" >> .env
else
        echo "warning found SP_ALLOWED_SUBNET so overwriting "
        sed -i "s#SP_ALLOWED_SUBNET=.*#SP_ALLOWED_SUBNET=${SN}#" .env
fi
else
	echo "no docker networks created, no physical nic cidr range checked or adjustment to .env file"
fi

