#!/bin/bash
set -ex

monitorUser="spot-monitor"

# Optional: Which topic should we send the notification of the instance is about to be terminated.
topicARN=""

while [ "$1" != "" ]; do
  case "$1" in
    --target-arn ) topicARN=$2; shift 2;;

    * )
    echo "usage $0 --target-arn ARN "
    exit 1 ;;
  esac
done

# Install script dependencies jq
sudo yum install -y jq git

#fetch and install script into a low permissioned user.
sudo useradd ${monitorUser}
sudo chmod ugo+xr /home/${monitorUser}
cd /home/${monitorUser}

#Set up logs
logFile="/var/log/${monitorUser}.log"
sudo touch ${logFile}
sudo chown ${monitorUser}:${monitorUser} ${logFile}

#Set up ssh access to github
sudo mkdir -p .ssh
tmpfile=$(mktemp /tmp/known_hosts.XXXXXX)
sudo ssh-keyscan github.com > ${tmpfile}
sudo mv ${tmpfile} .ssh/known_hosts
sudo chown --recursive ${monitorUser}:${monitorUser} .ssh
sudo chmod go-rxw,u-x .ssh/*

#Clone the monitor
sudo -u ${monitorUser} git clone –depth 1 git@github.com:stSoftwareAU/aws-spot-termination-monitor.git monitor

# Run the monitor in background
sudo -u ${monitorUser} monitor/run.sh --topic-arn ${topicARN} > ${logFile} &
