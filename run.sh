#!/bin/bash
set -e
mode="monitor"
email=""

init() {
	while true; do
	  case "$1" in
			--test ) mode="test"; shift ;;
			--email ) email=$2; shift 2;;

	    * ) break ;;
	  esac
	done

	identityJSON=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document`

	instanceId=$( jq -r '.instanceId'<<<${identityJSON} )
	region=$( jq -r '.region'<<<${identityJSON} )

	instanceJSON=`aws ec2 describe-instances --instance-ids ${instanceId} --region ${region}`

	asName=$( jq -r '.Reservations[0].Instances[0].Tags[]| select(.Key == "aws:autoscaling:groupName") .Value'<<<${instanceJSON} )

	if [[ -z $asName ]]; then
	   echo "no autoscale groupd for: $ID"
	   exit 1;
	fi
}

notified() {

	# OK We have << 2 minutes to complete all the work.
	# Start coping the logs in the background.
	echo "shutting down"

	asJSON=`aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $asName --region ${region}`

	minSize=$( jq -r '.AutoScalingGroups[0].MinSize'<<<${asJSON} );
	maxSize=$( jq -r '.AutoScalingGroups[0].MaxSize'<<<${asJSON} );

	onDemandBaseCapacity=$( jq -r '.AutoScalingGroups[0].MixedInstancesPolicy.OnDemandBaseCapacity'<<<${asJSON} );
	targetOnDemandBaseCapacity=1

	if [[ $onDemandBaseCapacity < $targetOnDemandBaseCapacity ]]; then

		targetOnDemandBaseCapacity=$onDemandBaseCapacity

		echo "Change onDemandBaseCapacity $onDemandBaseCapacity -> $targetOnDemandBaseCapacity"
		aws autoscaling update-auto-scaling-group \
			--auto-scaling-group-name $asName \
			--region ${region} \
			--mixed-instances-policy "{\"InstancesDistribution\": {\"OnDemandBaseCapacity\":$targetOnDemandBaseCapacity}"
	fi

	if [[ $minSize == 1 && $maxSize > 1 ]]; then

		desiredCapacity=$( jq -r '.AutoScalingGroups[0].DesiredCapacity'<<<${asJSON} );

		targetMinSize=2
		targetDesiredCapacity=$desiredCapacity

		if [[ $targetMinSize > $targetDesiredCapacity ]]; then
			targetDesiredCapacity=$targetMinSize
			echo "Increase DesiredCapacity $desiredCapacity -> $targetDesiredCapacity"
		fi

		echo "Increase MinSize $minSize -> $targetMinSize"

		aws autoscaling update-auto-scaling-group \
	    --auto-scaling-group-name $asName \
			--region ${region} \
			--desired-capacity $targetDesiredCapacity \
			--min-size $targetMinSize
	fi

	launchConfigurationName=$( jq -r '.AutoScalingGroups[0].LaunchConfigurationName'<<<${asJSON} )
	costlyConfigurationName="${launchConfigurationName/\#spot/#costly}";
	if [[ "$launchConfigurationName" != "$costlyConfigurationName" ]]; then
		aws autoscaling update-auto-scaling-group \
		  --auto-scaling-group-name $asName \
	    --launch-configuration-name $costlyConfigurationName

		if [[ $asName =~ .*-web ]]; then
			minSize=$( jq -r '.AutoScalingGroups[0].MinSize'<<<${asJSON} );
			if [[ $minSize < 2 ]]; then
			desiredCapacity=$( jq -r '.AutoScalingGroups[0].DesiredCapacity'<<<${asJSON} );

			maxSize=$( jq -r '.AutoScalingGroups[0].MaxSize'<<<${asJSON} );
			increaseCapacity=$(($desiredCapacity + 1))
			if [[ $increaseCapacity > $maxSize ]]; then
				increaseCapacity=$maxSize;
			fi

			if [[ $increaseCapacity < $minSize ]]; then
				increaseCapacity=$minSize;
			fi
			aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asName \
					--desired-capacity $increaseCapacity \
					--min-size $increaseCapacity
			fi
		fi
	fi

	# Stop monitoring once notified of termination.
	bash -x ../drainInstance.sh $ID

	# if we have removed the instance from the load balancer then we need to make sure this this instance actually shuts down.
	echo "The instance should be terminated in less than 2 minutes but just shutdown in five if this is not the case for some reason"
	sudo shutdown +5

  if [ -z "$email" ]; then

#			-a /var/log/ec2-user/termination_notice.log \

		echo "$launchConfigurationName -> $costlyConfigurationName" |mailx \
			-a /tmp/spot-termination.json \
			-s "Spot $ID terminated for $asName" $email
	fi

	exit
}

monitor() {

	#Don't stop no matter what ( we will not be restarted).
	set +e
	while true
	do
	  res=$(curl -s -o /tmp/spot-termination.json -w '%{http_code}\n' http://169.254.169.254/latest/meta-data/spot/instance-action)

	  if ((res == 200)); then
      notified
	  else
	    sleep 5
	  fi
	done
}

init $@

if [ "$mode" == "test" ]; then
	set -x			# activate debugging from here

	notified
fi

monitor
