#!/bin/bash
set -ex

monitorUser="spot-monitor"

# Optional: Which topic should we send the notification of the instance is about to be terminated.
topicARN=""
resetMinSize=""
resetOnDemandBaseCapacity=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --topic-arn )
      topicARN=$2
      shift;;
    --reset-min-size)
      resetMinSize=$2
      shift
      ;;
    --reset-on-demand-base-capacity)
      resetOnDemandBaseCapacity=$2
      shift
    * )
      echo "Unknown parameter passed: $1"
      exit 1 ;;
  esac
  if [[ $# -gt 0 ]]; then
    shift
  fi
done

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
cmd="monitor/run.sh"
if [ ! -z "${resetOnDemandBaseCapacity}" ]; then
  cmd="$cmd --reset-on-demand-base-capacity ${resetOnDemandBaseCapacity}"
fi

if [ ! -z "${resetMinSize}" ]; then
  cmd="$cmd --reset-min-size ${resetMinSize}"
fi

if [ ! -z "${topicARN}" ]; then
  cmd="$cmd --topic-arn ${topicARN}"
fi

sudo -u ${monitorUser} ${cmd} > ${logFile} &
