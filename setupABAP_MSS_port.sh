#!/bin/bash
#set -x
BOLD='\033[1m'
RESET='\033[0m'
INST=$(/usr/sap/hostctrl/exe/saphostctrl -function ListInstances | head -1 | awk '{print $6}')

MSG_INST=$(sapcontrol -nr "${INST}" -function GetSystemInstanceList | grep MESSAGESERVER|awk -F, '{print $2}'|sed "s/ //g")
ABAP_INST=$(sapcontrol -nr "${INST}" -function GetSystemInstanceList | grep -v MESSAGESERVER| tail -1|awk -F, '{print $2}'|sed "s/ //g")

PREFIX_HTTPS_PORT="446"
TIMEOUT_SETTING="TIMEOUT=600,PROCTIMEOUT=60"
GLOBAL_HOST=$(sapcontrol -nr "${MSG_INST}" -function ParameterValue SAPGLOBALHOST -format script | grep '^0 : ' | cut -d' ' -f3)
#HTTPS_PARAMETER_NAME=$(sapcontrol -nr ${MSG_INST} -function ParameterValue | tr -d '\r' |grep -e "icm/server_port_" |grep -e "=$" |head -1)

port_scan () {
        find /sapmnt/"${SAPSYSTEMNAME}"/profile -maxdepth 1 -type f |while read i; do grep -v "^#" $i |sed -n "s/.*PORT=\([0-9].*\).*/\1/p"  | awk -F, '{print $1}' ; done
}

if [[ "${#MSG_INST}" -lt 2 ]];then
        MSG_INST="0${MSG_INST}"
fi
if [[ "${#ABAP_INST}" -lt 2 ]];then
        ABAP_INST="0${ABAP_INST}"
fi

#if [[ ! -f "/usr/sap/${SAPSYSTEMNAME}/D${ABAP_INST}/sec/SAPSSLS.pse" ]];then
#        echo "cant copy SAPSSLS.pse does not exist in instnace D${ABAP_INST}"
#        exit 1
#elif [[ ! -f "/usr/sap/${SAPSYSTEMNAME}/ASCS${MSG_INST}/sec/SAPSSLS.pse" ]];then
#        echo "copying instance pse to message server = cp /usr/sap/${SAPSYSTEMNAME}/D${ABAP_INST}/sec/SAPSSLS.pse /usr/sap/${SAPSYSTEMNAME}/ASCS${MSG_INST}/sec/"
#        cp /usr/sap/"${SAPSYSTEMNAME}"/D"${ABAP_INST}"/sec/SAPSSLS.pse /usr/sap/"${SAPSYSTEMNAME}"/ASCS"${MSG_INST}"/sec/
#else
#        echo "SAPSSLS.pse already exists for Message Server"
#        echo "creating a copy of the existing pse - SAPSSLS-backup-$$.pse"
#        cp /usr/sap/"${SAPSYSTEMNAME}"/ASCS"${MSG_INST}"/sec/SAPSSLS.pse /usr/sap/"${SAPSYSTEMNAME}"/ASCS"${MSG_INST}"/sec/SAPSSLS-backup-$$.pse
#        echo "copying instance pse to message server = cp /usr/sap/${SAPSYSTEMNAME}/D${ABAP_INST}/sec/SAPSSLS.pse /usr/sap/${SAPSYSTEMNAME}/ASCS${MSG_INST}/sec/"
#        cp /usr/sap/"${SAPSYSTEMNAME}"/D"${ABAP_INST}"/sec/SAPSSLS.pse /usr/sap/"${SAPSYSTEMNAME}"/ASCS"${MSG_INST}"/sec/
#fi

if sapcontrol -nr "${MSG_INST}" -function GetAccessPointList |grep msg_server |grep -w HTTPS &>/dev/null; then
        echo "Existing HTTPS parameters defined for Message server as follows"
        grep "HTTPS"  /usr/sap/"${SAPSYSTEMNAME}"/SYS/profile/"${SAPSYSTEMNAME}"_ASCS"${MSG_INST}"_"${GLOBAL_HOST}"
        HTTPS_ALREADY_DEFINED="YES"

else
        echo "add missing message server HTTPS port in Message Server profile"
        (( C=0 ))
        ABAP_MS_SERV_PORT=$(sapcontrol -nr "${MSG_INST}" -function ParameterValue ms/server_port_${C} -format script |grep "^0 : "| cut -d' ' -f3 )
        while [[ "${ABAP_MS_SERV_PORT}" != ""  ]]
        do
                (( C++ ))
                ABAP_MS_SERV_PORT=$(sapcontrol -nr "${MSG_INST}" -function ParameterValue ms/server_port_${C} -format script |grep "^0 : "| cut -d' ' -f3)
                echo "$ABAP_MS_SERV_PORT"
        done
        echo "new message server port for HTTPS = ms/server_port_${C}"

#       echo "${HTTPS_PARAMETER_NAME}PROT=HTTPS,PORT=${PREFIX_HTTPS_PORT}\$\$,${TIMEOUT_SETTING}" >>  "${SAPSYSTEMNAME}_ASCS${MSG_INST}_${GLOBAL_HOST}"
        echo  "${SAPSYSTEMNAME}_ASCS${MSG_INST}_${GLOBAL_HOST}"

fi
echo "--Detected these PORTS -- manual checks also required"
port_scan |sort -n
echo "--end of PORT scan------"
port_scan |grep -w "${PREFIX_HTTPS_PORT}${MSG_INST}"
retVal=$?
if [[ "${retVal}" == "0" ]];then
        echo "Matching Port found for default ${PREFIX_HTTPS_PORT}${MSG_INST} you need to pick another free port from the scanned ports above   "
        echo "check the following line in the ${SAPSYSTEMNAME}_ASCS${MSG_INST}_${GLOBAL_HOST} profile"
        grep -w "PROT=HTTPS" /usr/sap/"${SAPSYSTEMNAME}"/SYS/profile/"${SAPSYSTEMNAME}"_ASCS"${MSG_INST}"_"${GLOBAL_HOST}" |grep "ms"
        #echo "#ms/server_port_${C} = PROT=HTTPS,PORT={PICK_UNIQUE_PORT},${TIMEOUT_SETTING}"
elif [[ "${HTTPS_ALREADY_DEFINED}" != "YES" ]];then
        echo -e "Add the following line to the ${BOLD}/usr/sap/${SAPSYSTEMNAME}/SYS/profile/${SAPSYSTEMNAME}_ASCS${MSG_INST}_${GLOBAL_HOST} ${RESET} profile"
        echo -e "${BOLD}ms/server_port_${C} = PROT=HTTPS,PORT=${PREFIX_HTTPS_PORT}${MSG_INST},${TIMEOUT_SETTING}${RESET}"
else
        echo "default PORT used ${PREFIX_HTTPS_PORT}${MSG_INST} is alredy in use by another service - need a unique port to setup"
        grep -w "${PREFIX_HTTPS_PORT}${MSG_INST}" /usr/sap/"${SAPSYSTEMNAME}"/SYS/profile/*
fi
echo "END OF PORT CHECKS"
echo -e "\ncheck timeouts match accross HTTPS server port settings"
echo "## ABAP instance"
sapcontrol -nr "${ABAP_INST}" -function ParameterValue | tr -d '\r' |grep "icm/server_port" | grep "HTTPS"
sapcontrol -nr "${ABAP_INST}" -function ParameterValue | tr -d '\r' |grep "icm/server_port" | grep "HTTPS" |sed "s/.*\(TIMEOUT=\)/\1/"
echo "## Message Server instance"
sapcontrol -nr "${MSG_INST}" -function ParameterValue | tr -d '\r' |grep "icm/server_port" | grep "HTTPS"
sapcontrol -nr "${MSG_INST}" -function ParameterValue | tr -d '\r' |grep "icm/server_port" | grep "HTTPS" |sed "s/.*\(TIMEOUT=\)/\1/"

