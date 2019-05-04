# Web server monitor for spot termination

To prevent/reduce publically visible web server outages yet allow the use of spot instance this script will monitor for spot termination notication and take actions immediately.

When notified that this instance will be terminated the following actions will be performed:-
1. increase the minimum ( starting another)
2. Make sure the autoscale group requests at least one server be on demand.
3. When there are other healthy servers in this target group remove this server from the target group.

```bash
sudo yum install -y jq mailx
curl https://raw.githubusercontent.com/stSoftwareAU/aws-spot-termination-monitor/master/run.sh --output spot-monitor.sh
bash -x spot-monitor.sh
```
