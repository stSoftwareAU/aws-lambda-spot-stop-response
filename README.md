# Monitor for spot termination and take actions immediately to prevent web server outage. 

Handles spot instance termination.
The spot termination script will monitor for spot termination notice. 

When notified that this instance will be stoped which will:-
1. increase the minimum ( starting another)
2. Make sure the autoscale group requests at least one server be on demand.
3. When there are other healthy servers in this target group remove this server from the target group.
