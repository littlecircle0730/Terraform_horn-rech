#!/bin/bash

SCRIPT_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd )"

PROJECT=$1
STAGE=$2

# Creates the small zip file
$SCRIPT_DIR/../handler/build.sh $PROJECT $STAGE

# Uploads the zip file to lambda and invalidates the cache
aws lambda update-function-code --function-name $PROJECT-$STAGE \
--zip-file fileb://handler/handler.zip --publish

# Creates a new cache
$SCRIPT_DIR/invoke.sh
