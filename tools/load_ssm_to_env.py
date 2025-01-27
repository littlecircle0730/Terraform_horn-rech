#!/usr/bin/env python

import os
import argparse
from dotenv import dotenv_values, set_key  # pip install python-dotenv

def ssm_client():
    import boto3
    return boto3.client('ssm')

def get_parameters_by_path(path):
    client = ssm_client()
    response = {"NextToken": None}
    while "NextToken" in response:
        kwargs = {"NextToken": response['NextToken']} if response['NextToken'] else {}
        response = client.get_parameters_by_path(
            Path=path,
            Recursive=True,
            WithDecryption=True,
            MaxResults=10,
            **kwargs
        )
        yield from response['Parameters']

parser = argparse.ArgumentParser()
parser.add_argument("project")
parser.add_argument("stage")
parser.add_argument("env")
args = parser.parse_args()

# Load existing .env file
env_path = args.env
env_config = dotenv_values(env_path)

# Initialize SSM client
client = ssm_client()

# Fetch parameters from SSM
ssm_path = f'/{args.project}/{args.stage}'
for param in get_parameters_by_path(ssm_path):
    env_name = os.path.basename(param['Name'])  # Extract the key name
    ssm_value = param['Value']

    # Update .env if needed
    if env_name not in env_config or env_config[env_name] != ssm_value:
        set_key(env_path, env_name, ssm_value)
        print(f'Updated .env: {env_name} = {ssm_value}')
    else:
        print(f'No changes needed for {env_name}')
