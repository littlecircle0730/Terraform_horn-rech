#!/bin/bash

LAMBDA_ARN=`terraform output -raw lambda_arn`

OUTPUT=`
aws lambda invoke \
    --function-name $LAMBDA_ARN \
    --invocation-type "RequestResponse" \
    --payload '{"raw_command": "import hornsense"}' \
    --log-type Tail \
    /dev/null
`

echo $OUTPUT | jq -r '.LogResult' | base64 --decode
