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
from boto3.dynamodb.conditions import Key, Attr
from datetime import datetime
from datetime import timedelta

patch(['boto3'])


def _(cmd):
    return subprocess.check_output(cmd.split())


# Seconds a stored result is served before the handler re-fetches it.
CACHE_MAX_AGE_SECONDS = 86400 * 3


def lambda_handler(event, context):
    start = datetime.now()
    now_epoch = int(start.timestamp())

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['TABLE_NAME'])
    title = event['queryStringParameters']['title']

    histories = table.query(
        KeyConditionExpression=Key('title').eq(title),
        ScanIndexForward=False
    )

    cached = histories['Items'][0] if histories['Count'] > 0 else None
    fresh = cached is not None and 'result' in cached and 'fetched_at' in cached \
        and now_epoch - int(cached['fetched_at']) < CACHE_MAX_AGE_SECONDS

    if fresh:
        result = json.loads(cached['result'])
        fetched_at = int(cached['fetched_at'])
    else:
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
        fetched_at = now_epoch

    completed = datetime.now()
    timestamp = start.strftime('%Y/%m/%d %H:%M:%S') + '.%03d' % (start.microsecond // 1000)
    history = {
        'title': title,
        'timestamp': timestamp,
        'completed': completed.strftime('%Y/%m/%d %H:%M:%S') + '.%03d' % (completed.microsecond // 1000),
        'event': json.dumps(event),
        'result': json.dumps(result),
        'is_error': 'error' in result,
        'fetched_at': fetched_at,
        'ttl': int((completed + timedelta(days=31)).timestamp())
    }
    table.put_item(Item=history)

    return {
        'isBase64Encoded': False,
        'statusCode': 200 if ('error' not in result) else 403,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps(result)
    }
