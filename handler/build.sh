#!/bin/bash
set -e

BUCKET=$1-$2-lambda
STAGE=$2

PIP_USE_FEATURE=2020-resolver

BASEDIR=$(dirname "$0")
cd $BASEDIR

rm -Rf handler .zappa-env zappa_settings.py handler.zip handler_hornsense-backend-production-*.zip handler_venv __pycache__ || true
rm -Rf hornsense-backend-production-*.tar.gz || true

PY=`which python3 || which python`
$PY -m pip install --upgrade virtualenv
$PY -m venv .zappa-env
deactivate || true
source .zappa-env/bin/activate

zappa package production
rm hornsense-backend-production-*.tar.gz
mv handler_hornsense-backend-production-*.zip handler.zip
unzip -oj handler.zip zappa_settings.py

python parser.py --stage $STAGE --bucket $BUCKET >> zappa_settings.py

zip handler.zip zappa_settings.py
zip handler.zip handler.py
