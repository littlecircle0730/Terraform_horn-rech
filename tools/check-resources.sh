#!/bin/bash

PROJECT=$1
STAGE=$2

function check_bucket() {
    B=$1
    ERROR=`aws s3 ls s3://$B/ 2>&1 1>/dev/null | tr -d '\n'`
    echo $ERROR | grep 'The specified bucket does not exist' 2>&1 > /dev/null
    CHECK=$?
    if [ "$CHECK" -eq "0" ] ; then
        echo $B":" "✓"
    else
        echo $B":" "✘" $ERROR
    fi
}

function check_plan_buckets() {
    F=$1
    BUCKETS=`
        cat $F |
        jq -r '
            .planned_values.root_module.resources[] |
            select(.type=="aws_s3_bucket") |
            .values.bucket
        '
    `
    for B in $BUCKETS; do
        check_bucket $B
    done
}

echo 'Computing plan...'
cd bootstrap
terraform plan \
    -out /tmp/tf-bootstrap.plan \
    -state /tmp/bootstrap.tfstate \
    -var project=$PROJECT \
    -var stage=$STAGE 2>&1 > /dev/null
terraform show -json /tmp/tf-bootstrap.plan > /tmp/tf-bootstrap.plan.json
cd ..

terraform plan \
    -out /tmp/tf.plan \
    -state /tmp/bootstrap.tfstate \
    -var-file=terraform.tfvars \
    -var project=$PROJECT \
    -var stage=$STAGE 2>&1 > /dev/null
terraform show -json /tmp/tf.plan > /tmp/tf.plan.json

echo 'Checking buckets...'
check_plan_buckets /tmp/tf.plan.json
check_plan_buckets /tmp/tf-bootstrap.plan.json
