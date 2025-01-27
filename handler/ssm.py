import os
import logging

logger = logging.getLogger(__name__)

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

ssm_param_path = os.getenv('AWS_SYSTEMS_MANAGER_PARAM_STORE_PATH')
if ssm_param_path:
    logger.info(f'Fetching parameters from {ssm_param_path}')
    response = get_parameters_by_path(ssm_param_path)
    for param in response:
        env_name = os.path.basename(param['Name'])
        os.environ[env_name] = param['Value']
        logger.info(f'- Parameter: {env_name}')
