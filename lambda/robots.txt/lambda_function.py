# -*- coding: utf-8 -*-
import json


def lambda_handler(event, context):
    return {
        'isBase64Encoded': False,
        'statusCode': 200,
        'headers': {
            'content-type': 'text/plain',
            'content-encoding': 'UTF-8',
        },
        'body': 'user-agent: *\ndisallow:/'
    }
