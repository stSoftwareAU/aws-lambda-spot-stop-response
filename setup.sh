#!/bin/bash
set -ex
#Defaults
monitorUser="spot-monitor"

# Install script dependencies jq
sudo yum install -y jq git

#fetch and install script into a low permissioned user.
sudo useradd ${monitorUser}
sudo chmod ugo+xr /home/${monitorUser}
cd /home/${monitorUser}

#Set up logs
logFile="/var/log/${monitorUser}.log"
touch ${logFile}

#Set up ssh access to github
sudo mkdir -p .ssh
tmpfile=$(mktemp /tmp/known_hosts.XXXXXX)
sudo ssh-keyscan github.com > ${tmpfile}
sudo mv ${tmpfile} .ssh/known_hosts
sudo chown --recursive ${monitorUser}:${monitorUser} .ssh
sudo chmod go-rxw,u-x .ssh/*

#Clone the monitor
sudo -u ${monitorUser} git clone --depth 1 https://github.com/stSoftwareAU/aws-spot-termination-monitor.git monitor

# Run the monitor in background
sudo -u ${monitorUser} monitor/run.sh $@ > ${logFile} &
