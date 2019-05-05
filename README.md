# Web server monitor for spot termination

To prevent/reduce publically visible web server outages yet allow the use of spot instance this script will monitor for spot termination notication and take actions immediately.

When notified that this instance will be terminated the following actions will be performed:-
1. Notify a topic ( if specified ) that this instance will be terminated
2. Increase the minimum ( starting another)
3. Make sure the autoscale group requests at least one server be on demand.
4. When there are other healthy servers in this target group remove this server from the target group.

## User Data
```bash
#!/bin/bash
# Install/Start a web server ( obviously replaced by your real web application)
yum install -y httpd
/bin/systemctl start httpd.service

# Optional: Which topic should we send the notification of the instance is about to be terminated.
topicARN="arn:aws:sns:ap-southeast-2:0000000000000:test"

# download and setup the spot monitor
setupURL="https://raw.githubusercontent.com/stSoftwareAU/aws-spot-termination-monitor/master/setup.sh"
curl -s ${setupURL} | bash -s --target-arn ${topicARN}

```
