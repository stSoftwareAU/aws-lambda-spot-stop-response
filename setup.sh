#!/bin/bash
set -ex

#Defaults
monitorUser="spot-monitor"

# Install script dependencies jq
yum install -y jq git

#fetch and install script into a low permissioned user.
useradd ${monitorUser}
chmod ugo+xr /home/${monitorUser}
cd /home/${monitorUser}

#Clone the monitor
sudo -u ${monitorUser} git clone --depth 1 https://github.com/stSoftwareAU/aws-spot-termination-monitor.git monitor

# Run the monitor in background
sudo -u ${monitorUser} monitor/run.sh $@ > /var/log/${monitorUser}.log &
