#!/bin/bash
#set -x


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

loop_docker_vol () {
    INDIVIDUAL_YML=${1}
	echo "processing ${INDIVIDUAL_YML}"
	yq '.volumes | keys | .[]' ${INDIVIDUAL_YML} |grep "${DOCKER_VOLUME_SUFFIX}" |egrep -v "_keys_|_info_" |while read i
	do

		CHECKVOL=$(docker volume inspect ${i} 2>/dev/null|jq -r '.[]|.Options.device')
		if [[ "${CHECKVOL}" != "" ]];then
			#ls -ld $LOCAL_DOCKER_VOLUME_DIR/${i}
			retVal=$?
			if [ $retVal -ne 0 ];then
				echo "error creating directory for volume-  exiting"
				exit 1
			fi
			#chgrp -R ${TX_SHARED_GROUP_NAME} $LOCAL_DOCKER_VOLUME_DIR/${i}
			#chmod g+w  $LOCAL_DOCKER_VOLUME_DIR/${i}
			#docker volume create  --driver local -o o=bind -o type=none -o device=$LOCAL_DOCKER_VOLUME_DIR/${i} ${i}
			cd  ${LOCAL_DOCKER_VOLUME_DIR}
			retVal=$(ask_new_input "$LOCAL_DOCKER_VOLUME_DIR/${i}")
			if [[ "${retVal}" == "yes" ]];then
				find  ${i} -mindepth 1 -delete

			fi
			cd ${CDIR}
		else
			echo "  no directory defined skipping"
		fi

	done
echo
}


extract_serv () {
	SERV=${2}


#LOCAL_DOCKER_VOLUME_DIR
read -p "Bring down and remove service ${SERV} container? (y/n): " confirm  </dev/tty
if [[ $confirm == [Yy] ]]; then
	docker compose -f c_docker_compose.yml  down ${SERV}  -v --rmi local --remove-orphans
	#DF=$(yq '.services[]|.build.dockerfile' $INDIVIDUAL_YML )
	loop_docker_vol ${1}
else
	echo "no action taken on containers"
fi

}


if [[ ! -d "${LOCAL_DOCKER_VOLUME_DIR}" ]];then
	echo "Chosen docker directory does not exist - nothing to reset, exiting"
	exit
fi

while read INDIVIDUAL_YML;do
echo $INDIVIDUAL_YML
SERV=$(yq '.services|keys[]' ${INDIVIDUAL_YML} )
echo ${SERV}
extract_serv ${INDIVIDUAL_YML} ${SERV}
done < <(ls *extracted*yml)
#done < <(yq '.services|keys[]' *extracted*yml)

#yq '.volumes | keys' robert_compose.yml|grep "vol1" |sed "s/- //" |while read i



cd ${CDIR}
