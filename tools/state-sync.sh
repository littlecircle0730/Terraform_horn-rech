#!/bin/bash

PROJECT=$1
STAGE=$2
OPERATION=$3

case $OPERATION in

  pull)
    aws s3 cp s3://$PROJECT-$STAGE-tfstate/backend.tfvars backend.tfvars
    aws s3 cp s3://$PROJECT-$STAGE-tfstate/terraform.tfvars terraform.tfvars
    aws s3 cp s3://$PROJECT-$STAGE-tfstate/bootstrap.tfvars bootstrap/terraform.tfvars
    aws s3 cp s3://$PROJECT-$STAGE-tfstate/bootstrap.tfstate bootstrap/terraform.tfstate
    aws s3 cp s3://$PROJECT-$STAGE-tfstate/.env $PROJECT-$STAGE.env
    ;;

  push)
    aws s3 cp backend.tfvars s3://$PROJECT-$STAGE-tfstate/backend.tfvars
    aws s3 cp terraform.tfvars s3://$PROJECT-$STAGE-tfstate/terraform.tfvars
    aws s3 cp bootstrap/terraform.tfvars s3://$PROJECT-$STAGE-tfstate/bootstrap.tfvars
    aws s3 cp bootstrap/terraform.tfstate s3://$PROJECT-$STAGE-tfstate/bootstrap.tfstate
    aws s3 cp $PROJECT-$STAGE.env s3://$PROJECT-$STAGE-tfstate/.env
    ;;

  *)
    echo "Valid operations: pull, push"
    ;;
esac
