# -*- coding: utf-8 -*-

import boto3
import json
import os
import subprocess
import urllib.parse

from base64 import b64decode
from boto3.dynamodb.conditions import Key, Attr
from datetime import datetime
from datetime import timedelta

ENCRYPTED = os.environ['ENCRYPTED_GOOGLE_API_KEY']
os.environ['GOOGLE_API_KEY'] = boto3.client('kms').decrypt(CiphertextBlob=b64decode(ENCRYPTED))['Plaintext'].decode('utf-8')
ENCRYPTED = os.environ['ENCRYPTED_GOOGLE_APP_ID']
os.environ['GOOGLE_APP_ID'] = boto3.client('kms').decrypt(CiphertextBlob=b64decode(ENCRYPTED))['Plaintext'].decode('utf-8')

def _(cmd):
    return subprocess.check_output(cmd)

def lambda_handler(event, context):
    start = datetime.now()

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('historySteamGame')

    scan = table.scan(
        FilterExpression=Attr('is_error').ne(True)
    )
    if 'LastEvaluatedKey' in scan:
        next_scan = {'LastEvaluatedKey': scan['LastEvaluatedKey']}
    else:
        next_scan = {}
    while 'LastEvaluatedKey' in next_scan:
        next_scan = table.scan(
            FilterExpression=Attr('is_error').ne(True),
            ExclusiveStartKey=scan['LastEvaluatedKey']
        )
        scan['Items'].extend(next_scan['Items'])

    items = map(lambda x:{'event': json.loads(x['event']),
                          'result': json.loads(x['result'])}, scan['Items'])

    histories = [y for y in items \
        if 'error' not in y['result'] and \
            (y['event']['queryStringParameters']['title'] == event['queryStringParameters']['title'] or
             y['result']['title'] == urllib.parse.unquote(event['queryStringParameters']['title'], encoding='utf-8'))]

    if len(histories) == 0 or \
        ('cache' in event['queryStringParameters'] and
                 event['queryStringParameters']['cache'] == 'no'):
        os.environ['REQUEST_URI'] = 'info_json.sh?title=' \
            + urllib.parse.quote_plus(event['queryStringParameters']['title'], safe='+', encoding='utf-8')
        json_string = ""
        try:
            json_string = _(['./info_json.sh'])
            result = json.loads(json_string)
        except:
            print("except:", json_string)
            raise
    else:
        result = histories[0]['result']

    completed = datetime.now()
    history = {
        'timestamp': start.strftime('%Y/%m/%d %H:%M:%S') + '.%03d' % (start.microsecond // 1000),
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
