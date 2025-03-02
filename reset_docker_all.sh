#!/bin/bash
#set -x
export SP_BOLD='\033[1m'
export SP_RESET='\033[0m'

if ! command -v yq &> /dev/null ;then
    echo "yq could not be found"
    exit 1
fi
. .env
CDIR=$(pwd)
DOCKER_SUFFIX="extracted-compose.yml"
DOCKER_VOLUME_SUFFIX="vol1"

ask_new_input () {
        msg="$1"
        echo "Volume directory: $ask" >&2
	echo "  ${msg}" >&2
        echo "reset / clear out volume directory? (y/n): "  >&2
        read confirm </dev/tty
        if [[ $confirm == [Yy] ]]; then
            echo "yes"
        else
            echo "no"
        fi

}

#LOCAL_DOCKER_VOLUME_DIR
if [[ ! -d "${LOCAL_DOCKER_VOLUME_DIR}" ]];then
	echo "Chosen docker directory does not exist - nothing to reset, exiting"
	exit
fi

read -p "Bring down and remove containers? (y/n): " confirm 
if [[ $confirm == [Yy] ]]; then
	docker compose -f c_docker_compose.yml  down  -v --rmi local --remove-orphans
else
	echo "no action taken on containers"
fi

#yq '.volumes | keys' robert_compose.yml|grep "vol1" |sed "s/- //" |while read i
while read DOCKER_FILE ;do
	echo "processing ${DOCKER_FILE}"
	yq '.volumes | keys | .[]' ${DOCKER_FILE} |grep "${DOCKER_VOLUME_SUFFIX}" |grep -Ev "_keys_|_info_" |while read i
	do

		CHECKVOL=$(docker volume inspect ${i} 2>/dev/null|jq -r '.[]|.Options.device')
		if [[ "${CHECKVOL}" != "" ]];then
			cd  "${LOCAL_DOCKER_VOLUME_DIR}" || echo "ERROR cd to ${LOCAL_DOCKER_VOLUME_DIR}"
			retVal=$(ask_new_input "$LOCAL_DOCKER_VOLUME_DIR/${i}")
			if [[ "${retVal}" == "yes" ]];then
				find  ${i} -mindepth 1 -delete
				echo -e "${SP_BOLD}Volume contents deleted from ${i}${SP_RESET}"
			else
				echo -e "${SP_BOLD}NO ACTION TAKEN${SP_RESET}"
			fi
			cd "${CDIR}"  || echo "ERROR cd to ${CDIR}"
		else
			echo "  no directory defined skipping"
		fi

	done
echo
done < <(ls *${DOCKER_SUFFIX})

cd "${CDIR}" || echo "ERROR cd to ${CDIR}"
