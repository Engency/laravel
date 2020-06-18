#!/bin/bash

currentDir=$(dirname "$0")

if [[ $(whoami) != "root" ]]; then
    echo 'Not logged in as root. This script needs elevated permissions. Aborting...'
    exit
fi

/bin/cp -uf "$currentDir"/engency /etc/init.d/engency
chmod u+x /etc/init.d/engency
/bin/cp -uf "$currentDir"/engency.service /etc/systemd/system/engency.service
systemctl daemon-reload
systemctl enable engency
