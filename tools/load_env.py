#!/bin/env python

import os
import argparse
from dotenv import dotenv_values  # pip install python-dotenv

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
parser.add_argument("--dry-run", action='store_true')
args = parser.parse_args()

config = dotenv_values(args.env)
client = ssm_client()

for param in get_parameters_by_path(f'/{args.project}/{args.stage}'):
    env_name = os.path.basename(param['Name'])
    if env_name in config and param['Value'] != config[env_name]:
        if not args.dry_run:
            client.put_parameter(
                Name=param['Name'],
                Value=config[env_name],
                Overwrite=True,
            )
        print(f'Parameter {param["Name"]} replaced from "{param["Value"]}" to "{config[env_name]}".')
