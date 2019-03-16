# -*- coding: utf-8 -*-

import boto3
import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), 'vendored'))

from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch
from boto3.dynamodb.conditions import Key, Attr

patch(['boto3'])


def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['TABLE_NAME'])

    xray_recorder.begin_subsegment('get_history')
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
    xray_recorder.end_subsegment()

    items = [{'timestamp': x['timestamp'],
              'result': json.loads(x['result']),
              'event': json.loads(x['event'])} for x in scan['Items']]
    titles = [x['result']['title'] for x in items]
    items2 = sorted(list({v['result']['title']: v for v in items}.values()),
                    key=lambda x: x['timestamp'],
                    reverse=True)
    histories = [('./search.html?title=' + y['event']['queryStringParameters']['title'],
                  y['result']['title'], titles.count(y['result']['title'])) for y in items2]

    return {
        'isBase64Encoded': False,
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps(histories)
    }
