# -*- coding: utf-8 -*-

import boto3
import json
import os

from boto3.dynamodb.conditions import Key, Attr
from datetime import datetime
from datetime import timedelta

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['TABLE_NAME'])

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

    items = [{'timestamp': x['timestamp'],
              'result': json.loads(x['result']),
              'event': json.loads(x['event'])} \
             for x in scan['Items']]
    titles = [x['result']['title'] for x in items]
    items2 = sorted(list({v['result']['title']:v for v in items}.values()),
                    key=lambda x:x['timestamp'],
                    reverse=True)
    histories = [('./search.html?title=' + y['event']['queryStringParameters']['title'],
                  y['result']['title'], titles.count(y['result']['title'])) for y in items2]

    return {
        'isBase64Encoded': False,
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps(histories)
    }
