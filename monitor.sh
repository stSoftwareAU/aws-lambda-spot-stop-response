#!/bin/bash
for pid in $(/usr/sbin/pidof -x termination_notice.sh); do
    if [ $pid != $$ ]; then
        echo "[$(date)] : termination_notice.sh : Process is already running with PID $pid"
        exit 1
    fi
done

DIR="$( cd -P "$( dirname "$BASH_SOURCE" )" && pwd -P )"
cd $DIR

./run.sh > /var/log/ec2-user/termination_notice.log 2>&1
