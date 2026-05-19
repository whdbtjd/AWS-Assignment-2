import base64
import gzip
import json
import os
import boto3

sns = boto3.client('sns')
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']


def lambda_handler(event, context):
    raw = base64.b64decode(event['awslogs']['data'])
    log_data = json.loads(gzip.decompress(raw))

    blocked = [
        e for e in log_data.get('logEvents', [])
        if _is_blocked(e)
    ]

    for entry in blocked:
        record = json.loads(entry['message'])
        _send_alert(record)


def _is_blocked(log_event):
    try:
        return json.loads(log_event['message']).get('action') == 'BLOCK'
    except Exception:
        return False


def _send_alert(record):
    ip       = record.get('httpRequest', {}).get('clientIp', 'Unknown')
    uri      = record.get('httpRequest', {}).get('uri', 'Unknown')
    rule     = record.get('terminatingRuleId', 'Unknown')
    country  = record.get('httpRequest', {}).get('country', 'Unknown')
    args     = record.get('httpRequest', {}).get('args', '')

    message = (
        f"WAF Attack Detected\n"
        f"{'─' * 40}\n"
        f"Source IP : {ip}\n"
        f"Country   : {country}\n"
        f"URI       : {uri}\n"
        f"Args      : {args}\n"
        f"Rule      : {rule}\n"
        f"Action    : BLOCK\n"
    )

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject='[WAF Alert] Attack Blocked',
        Message=message,
    )
