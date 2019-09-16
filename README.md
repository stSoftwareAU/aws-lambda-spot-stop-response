# Web server monitor for spot termination

To prevent/reduce ​publicly visible web server outages yet allow the use of spot instance this script will monitor for spot termination ​notification and take actions immediately.

When notified that this instance will be terminated the following actions will be performed:-
1. Notify a topic ( if specified ) that this instance will be terminated
2. Increase the minimum ( starting another)
3. Make sure the autoscale group requests at least one server be on demand.
4. When there are other healthy servers in this target group remove this server from the target group.

## User Data
```bash
#!/bin/bash
#
# Install/Start a web server ( obviously replaced by your real web application)
# Only here as an example.
yum install -y httpd
/bin/systemctl start httpd.service

# Optional: Which topic should we send the notification of the instance is about to be terminated.
topicARN="arn:aws:sns:ap-southeast-2:0000000000000:test"

# download and setup the spot monitor
setupURL="https://raw.githubusercontent.com/stSoftwareAU/aws-spot-termination-monitor/master/setup.sh"
curl -s ${setupURL} -o setup.sh
bash setup.sh --topic-arn ${topicARN} --reset-min-size 1 --reset-on-demand-base-capacity 0
```

## IAM Role Permissions for this monitor
```JSON
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "sns:Publish",
                "ec2:DescribeInstances",
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:UpdateAutoScalingGroup",
                "autoscaling:DescribeLoadBalancerTargetGroups"
            ],
            "Resource": "*"
        }
    ]
}
```
