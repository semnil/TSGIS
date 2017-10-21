# -*- coding: utf-8 -*-

import boto3
import json

from boto3.dynamodb.conditions import Key, Attr
from datetime import datetime
from datetime import timedelta

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('historySteamGame')

    reference_time = datetime.now() - timedelta(days=30)
    scan = table.scan(
        FilterExpression=Attr('timestamp').gt(reference_time.strftime('%Y/%m/%d %H:%M:%S') +
                                              '.%03d' % (reference_time.microsecond // 1000))
    )

    items = [{'timestamp': x['timestamp'],
            'result': json.loads(x['result']),
            'event': json.loads(x['event'])}\
        for x in scan['Items'] if 'result' in x and 'error' not in json.loads(x['result'])]
    items2 = sorted(list({v['result']['title']:v for v in items}.values()),
                    key=lambda x:x['timestamp'],
                    reverse=True)
    histories = [('./search.html?title=' + y['event']['queryStringParameters']['title'],
        y['result']['title']) for y in items2]

    return {
        'isBase64Encoded': False,
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps(histories)
    }
