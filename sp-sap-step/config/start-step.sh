#!/bin/bash

set -x
. shared_logging.sh

HOST_FQDN=$(hostname -f)

INST_LOCFILE="/home/step/.step/authorities/${SP_AUTH_NAME}/config/ca.json"
ACME_PROV="${SP_PROV_NAME}-ACME"

initialise_step () {

		loginfo "initialise step"
                step ca init   --deployment-type=standalone --provisioner="${SP_PROV_NAME}"  --name="${SP_STEP_NAME}" --context="${SP_CONT_NAME}" --authority="${SP_AUTH_NAME}" --dns=localhost --dns="${HOST_FQDN}" --dns="${SP_CONTAINER_NAME}" --address="${SP_ADDRESS}" --remote-management=${SP_REMOT_MAN} --password-file <(set +x;echo -n $(shared_get_info.sh STEP PW) ;set -x)

}

renew () {
		loginfo "renew"

}

config_file () {
		loginfo "config_file"

}


startup () {

		loginfo "startup step"
		step-ca   --password-file <(set +x;echo -n $(shared_get_info.sh STEP PW);set -x) > /proc/1/fd/1 2>/proc/1/fd/2  &
		sleep 10

}


post_startup_init () {

		loginfo "post initialisation steps add a superstep user and provisioner"
                #Some changes made that these commands now fail in step due to "no admin cred.. found" but still adds the superstep account -
                step ca admin add superstep "${SP_PROV_NAME}" --admin-subject=step --admin-password-file=<(set +x;echo -n $(shared_get_info.sh STEP PW);set -x) --super
                step ca admin remove step  --admin-subject=superstep --admin-password-file=<(set +x;echo -n $(shared_get_info.sh STEP PW);set -x)
                step ca admin list  --admin-subject=superstep --admin-password-file=<(set +x;echo -n $(shared_get_info.sh STEP PW);set -x)
                
                step ca provisioner update "${SP_PROV_NAME}" --admin-provisioner="${SP_PROV_NAME}" --x509-max-dur=${SP_CERT_MAX_DUR} --admin-password-file=<(set +x;echo -n $(shared_get_info.sh STEP PW);set -x) --admin-subject=superstep

                step ca provisioner add "${ACME_PROV}" --type ACME  --admin-provisioner="${SP_PROV_NAME}" --admin-password-file=<(set +x;echo -n $(shared_get_info.sh STEP PW);set -x) --admin-subject=superstep
                step ca provisioner update "${ACME_PROV}"  --admin-provisioner="${SP_PROV_NAME}"  --x509-max-dur="${SP_CERT_MAX_DUR}" --admin-password-file=<(set +x;echo -n $(shared_get_info.sh STEP PW);set -x) --admin-subject=superstep

                step ca provisioner list 

                loginfo "STEP VERSION INFO: $(step --version | paste -d " " - - )"
                loginfo "setup of step-ca completed"

}

stopapp () {

	loginfo "stopping "
        pkill -P $$

}

shutdown_stopapp () {

	stopapp
	exit 0

}

check_step () {

                loginfo " health check "; 
}


andcheck () {

	loginfo "sleeping and checking step ca health output on loop"
        while true
        do
                step ca health
                retVal=$?
                if [ $retVal -eq 0 ];then
                        loginfo "step ca health check returned ok"
                        loginfo "step ca health check returned ok" > /proc/1/fd/1 2>/proc/1/fd/2  &
		else
			logerr "step ca health check is negative"
			logerr "step ca health check is negative" > /proc/1/fd/1 2>/proc/1/fd/2  &
                fi
        sleep 30m
        done


}

trap shutdown_stopapp TERM INT

shared_get_info.sh STEP PW &>/dev/null
retVal=$?
if [[ $retVal -eq 0 ]];then
        if [ ! -f ${INST_LOCFILE} ];then
                loginfo "setup step-ca"
                initialise_step
        #        config_file
                startup
		post_startup_init
         #       sleep 25
                andcheck

        else
        #        renew
                startup
                andcheck
        fi
else
        logerr "ERROR: cant access security info from age process - step-ca is not setup"
fi

#catch all infinite loop
tail -f /dev/null

