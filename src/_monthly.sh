#!/bin/bash
# CHECK FOR UPDATES: https://github.com/maxstoyanov/bashup

$PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games

ssh_pathprefix="monthly"

bash ./email.sh ${ssh_pathprefix}
bash ./intranet.sh ${ssh_pathprefix}
