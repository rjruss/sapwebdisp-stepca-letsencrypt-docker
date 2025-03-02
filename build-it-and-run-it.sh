#!/bin/bash
. .env
if [[ $(id -u) -eq 0 ]]; then
    echo "This script is best to run when logged in as user $LOCAL_DOCKER_USER"
    exit 1
fi

if [[ ! -f "./sp-sap-image/bin/SAPWEBDISP_SP_235-80007304.SAR" || ! -f "./sp-sap-image/bin/SAPCAR" ]]; then
    echo "Error: One or both files are missing in ./sp-sap-image/bin"
    echo "going to try and download "
	CDIR=$(pwd)
	cd ./sp-sap-image/bin || { echo "Download script directory not found"; exit 3; }
	. ./downloadSAPsoftware.sh
	retVal=$?
	if [[ "${retVal}" != "0" ]];then
		echo "exit - won't proceed without SAPCAR or SAPWEBDISP_SP_235-80007304.SAR files"
		exit 4
	fi
	cd "${CDIR}" || { echo "Error with download process"; exit 5; }
fi

#Check if the custom root certificate directory exists, if not create it
cd ./sp-sap-image/rootcerts  2>/dev/null  || mkdir ./sp-sap-image/rootcerts

INCLUDE_DOCKER_FILE="c_docker_compose.yml"
echo "build base image"
docker compose -f sp-sap-img.yml --progress plain build  --no-cache

#if docker images | grep -q "sap-img"; then
if docker images | grep -Eq "sap-img|sap-webshared-img"; then
	echo "build step, postgres and gitea together"
	echo "include:" > ${INCLUDE_DOCKER_FILE}
	while read i; do
	echo "  - ${i}" >> ${INCLUDE_DOCKER_FILE}
	done < <(ls *extracted*yml)

	docker compose -f ${INCLUDE_DOCKER_FILE} --progress plain build  --no-cache
	echo "startup"
	docker compose -f ${INCLUDE_DOCKER_FILE} up
else
	echo "some issue building base image exiting"
	exit 1
fi


#docker cp sap-step-run:/home/step/.step/authorities/basestepCA/certs/root_ca.crt root_ca.crt

