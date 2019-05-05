#!/bin/bash
set -e
mode="monitor"
topicARN=""
resetMinSize=""
resetOnDemandBaseCapacity=""

init() {
  while [[ "$#" -gt 0 ]]; do
     case "$1" in
       --test)
         mode="test"
         ;;
       --reset-min-size)
         resetMinSize=$2
         shift
         ;;
       --reset-on-demand-base-capacity)
         resetOnDemandBaseCapacity=$2
         shift
         ;;
       --topic-arn)
         topicARN=$2
         shift ;;
       *)
         echo "Unknown parameter passed: $1"
         exit 1 ;;
     esac
     if [[ $# -gt 0 ]]; then
	    shift
	  fi
  done

  identityJSON=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document`

  instanceId=$( jq -r '.instanceId'<<<${identityJSON} )
  region=$( jq -r '.region'<<<${identityJSON} )

  instanceJSON=`aws ec2 describe-instances --instance-ids ${instanceId} --region ${region}`

  auto_scale_group=$( jq -r '.Reservations[0].Instances[0].Tags[]| select(.Key == "aws:autoscaling:groupName") .Value'<<<${instanceJSON} )

  if [[ -z $auto_scale_group ]]; then
     echo "no autoscale groupd for: $ID"
     exit 1;
  fi
}

drainInstance() {

    target_groups_json=`aws autoscaling describe-load-balancer-target-groups \
      --region ${region} \
      --auto-scaling-group-name "${auto_scale_group}"`

    target_groups=$(jq -r '.LoadBalancerTargetGroups[] | .LoadBalancerTargetGroupARN'<<<"${target_groups_json}")

    #De-register this instance from each target group
    for target_group_arn in "${target_groups}"; do
        targets_json=$( \
          aws elbv2 describe-target-health \
            --region ${region} \
            --target-group-arn "${target_group_arn}" \
        )
        number_of_healthy_targets=$(jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length' <<< "${targets_json}")
        if [ $number_of_healthy_targets -gt 1 ] ]; then
            aws elbv2 deregister-targets \
              --region ${region} \
              --target-group-arn "${target_group_arn}" \
              --targets Id="${instance_ID}"
        fi
    done
}

notified() {

  # OK We have << 2 minutes to complete all the work.
  # Start coping the logs in the background.
  echo "Spot $ID terminated for $auto_scale_group"
  if [ ! -z "$topicARN" ]; then
    aws sns publish \
      --region ${region} \
      --topic-arn $topicARN \
      --subject "Spot $ID terminated for $auto_scale_group" \
      --message file:///tmp/spot-termination.json
  fi

  asJSON=`aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $auto_scale_group --region ${region}`

  minSize=$( jq -r '.AutoScalingGroups[0].MinSize'<<<${asJSON} );
  maxSize=$( jq -r '.AutoScalingGroups[0].MaxSize'<<<${asJSON} );

  onDemandBaseCapacity=$( jq -r '.AutoScalingGroups[0].MixedInstancesPolicy.OnDemandBaseCapacity'<<<${asJSON} );
  targetOnDemandBaseCapacity=1
  if [[ $onDemandBaseCapacity > $targetOnDemandBaseCapacity ]]; then

    targetOnDemandBaseCapacity=$onDemandBaseCapacity
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
      --auto-scaling-group-name $auto_scale_group \
      --region ${region} \
      --desired-capacity $targetDesiredCapacity \
      --min-size $targetMinSize \
      --mixed-instances-policy "\{\"InstancesDistribution\": \{\"OnDemandBaseCapacity\":${targetOnDemandBaseCapacity}\}\}"
  elif [[ $onDemandBaseCapacity < $targetOnDemandBaseCapacity ]]; then

    targetOnDemandBaseCapacity=$onDemandBaseCapacity

    echo "Change onDemandBaseCapacity $onDemandBaseCapacity -> $targetOnDemandBaseCapacity"
    aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name $auto_scale_group \
      --region ${region} \
      --mixed-instances-policy "\{\"InstancesDistribution\": \{\"OnDemandBaseCapacity\":${targetOnDemandBaseCapacity}\}\}"
  fi

  drainInstance

  # Stop monitoring once notified of termination.
  exit
}

# Reset the min and on demand capacity on successful start of a new server.
reset()
{
  if [ ! -z "$resetOnDemandBaseCapacity" ]; then
    aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name $auto_scale_group \
      --region ${region} \
      --mixed-instances-policy "\{\"InstancesDistribution\": \{\"OnDemandBaseCapacity\":${resetOnDemandBaseCapacity}\}\}"
  fi

  if [ ! -z "$resetMinSize" ]; then
    aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name $auto_scale_group \
      --region ${region} \
      --min-size $resetMinSize
  fi
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

reset

monitor
