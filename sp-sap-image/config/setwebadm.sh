#!/bin/bash

rm -rf /srv/usr/sap/webdisp/icmauth.txt

ADM_PW=$(set +x;shared_get_info.sh WEBSTEP ADM_PW;set -x)

#tmux kill-session -t SetAdm:
tmux new-session -d -s SetAdm
tmux send-keys -t SetAdm: "wdispmon -a  pf=/srv/usr/sap/webdisp/sapwebdisp.pfl" "Enter"
sleep 1
tmux send-keys -t SetAdm: "Enter"
sleep 1
tmux send-keys -t SetAdm: "y" "Enter"
tmux send-keys -t SetAdm: "a" "Enter"
tmux send-keys -t SetAdm: "webadm" "Enter"
tmux send-keys -t SetAdm: "${ADM_PW}" "Enter"
tmux send-keys -t SetAdm: "${ADM_PW}" "Enter"
tmux send-keys -t SetAdm:  "Enter"
tmux send-keys -t SetAdm:  "Enter"
tmux send-keys -t SetAdm:  "Enter"
tmux send-keys -t SetAdm: "s"  "Enter"
tmux send-keys -t SetAdm:  "Enter"
tmux send-keys -t SetAdm: "q"  "Enter"
tmux kill-session -t SetAdm:
