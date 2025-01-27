#!/bin/bash

SCRIPT_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd )"

PROJECT=$1
STAGE=$2

INSTANCE_ID=`aws ec2 describe-instances --filters "Name=tag:Name,Values=$PROJECT-$STAGE-bastion" --output text --query 'Reservations[*].Instances[*].InstanceId'`

ssh ${@:3} -o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'" ubuntu@$INSTANCE_ID
