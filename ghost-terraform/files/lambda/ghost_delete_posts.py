import os
import json
import requests # pip install requests
import jwt      # pip install pyjwt
from datetime import datetime as date

import boto3

def get_secret(name, version=None):
    secrets_client = boto3.client("secretsmanager")
    kwargs = {'SecretId': "ghost_token"}
    if version is not None:
        kwargs['VersionStage'] = version
    response = secrets_client.get_secret_value(**kwargs)
    return response['SecretString']

def lambda_handler(event, context):

    key_name = "ghost_token"
    key = get_secret(key_name)
    
    id, secret = key.split(':')
    iat = int(date.now().timestamp())
    
    header = {'alg': 'HS256', 'typ': 'JWT', 'kid': id}
    payload = {
        'iat': iat,
        'exp': iat + 5 * 60,
        'aud': '/canary/admin/' 
    }
    
    token = jwt.encode(payload, bytes.fromhex(secret), algorithm='HS256', headers=header)
    headers = {'Authorization': 'Ghost {}'.format(token)}
    
    # url = 'http://ghost-alb-1666353833.us-east-1.elb.amazonaws.com/ghost/api/canary/admin/db/'
    url = os.environ['GHOST_URL']
    r = requests.delete(url, headers=headers)

    return {
        'statusCode': 200,
        'body': json.dumps(print(token))
    }

