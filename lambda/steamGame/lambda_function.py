# -*- coding: utf-8 -*-

import boto3
import json
import os
import subprocess
import sys
import urllib.parse

sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), 'vendored'))

from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch
from base64 import b64decode
from boto3.dynamodb.conditions import Key, Attr
from datetime import datetime
from datetime import timedelta

patch(['boto3'])

ENCRYPTED = os.environ['ENCRYPTED_GOOGLE_API_KEY']
os.environ['GOOGLE_API_KEY'] = boto3.client('kms').decrypt(CiphertextBlob=b64decode(ENCRYPTED))['Plaintext'].decode(
    'utf-8')
ENCRYPTED = os.environ['ENCRYPTED_GOOGLE_APP_ID']
# os.environ['GOOGLE_APP_ID'] = boto3.client('kms').decrypt(CiphertextBlob=b64decode(ENCRYPTED))['Plaintext'].decode(
#     'utf-8')
os.environ['GOOGLE_APP_ID'] = os.environ['GOOGLE_SEARCH_KEY']


def _(cmd):
    return subprocess.check_output(cmd.split())


def lambda_handler(event, context):
    start = datetime.now()

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['TABLE_NAME'])
    title = event['queryStringParameters']['title']

    histories = table.query(
        KeyConditionExpression=Key('title').eq(title),
        ScanIndexForward=False
    )

    if histories['Count'] == 0 or \
            ('cache' in event['queryStringParameters'] and
             event['queryStringParameters']['cache'] == 'no'):
        os.environ['REQUEST_URI'] = 'info_json.sh?title=' \
                                    + urllib.parse.quote_plus(event['queryStringParameters']['title'], safe='+',
                                                              encoding='utf-8')
        json_string = ""
        xray_recorder.begin_subsegment('get_information')
        try:
            json_string = _('bash info_json.sh')
            print("json_string:", json_string)
            result = json.loads(json_string)
        except Exception as e:
            print("exception:", e)
            raise
        xray_recorder.end_subsegment()
    elif histories['Count'] > 0 and 'result' in histories['Items'][0]:
        result = json.loads(histories['Items'][0]['result'])
    else:
        result = {}

    completed = datetime.now()
    timestamp = start.strftime('%Y/%m/%d %H:%M:%S') + '.%03d' % (start.microsecond // 1000)
    history = {
        'title': title,
        'timestamp': timestamp,
        'completed': completed.strftime('%Y/%m/%d %H:%M:%S') + '.%03d' % (completed.microsecond // 1000),
        'event': json.dumps(event),
        'result': json.dumps(result),
        'is_error': 'error' in result,
        'ttl': int((completed + timedelta(days=31)).timestamp())
    }
    table.put_item(Item=history)

    return {
        'isBase64Encoded': False,
        'statusCode': 200 if ('error' not in result) else 403,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps(result)
    }
