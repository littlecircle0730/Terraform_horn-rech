import os 
import argparse
from zappa_settings import ENVIRONMENT_VARIABLES

parser = argparse.ArgumentParser(description='Update zappa settings.')
parser.add_argument('--stage', required=True)
parser.add_argument('--bucket', required=True)
args = parser.parse_args()

ENVIRONMENT_VARIABLES['DJANGO_CONFIGURATION'] = {
    'dev': 'Development',
    'prod': 'Production',
    'rech': 'Research',
}[args.stage]

ARCHIVE_PATH = f's3://{args.bucket}/project.tar.gz'

print()
print('ENVIRONMENT_VARIABLES', '=', ENVIRONMENT_VARIABLES)
print('ARCHIVE_PATH', '=', f'"{ARCHIVE_PATH}"')
print()

here = os.path.dirname(os.path.realpath(__file__))
with open(os.path.join(here, 'ssm.py'), 'r') as f:
    print(f.read())
print()