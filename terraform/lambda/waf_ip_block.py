"""WAF BLOCK 경보 시 Logs Insights로 공격 IP 추출 → IP Set에 등록."""

import json
import os
import time

import boto3

logs = boto3.client("logs")
# Lambda 실행 리전(us-east-1) — AWS_REGION env는 예약어라 설정 불가
wafv2 = boto3.client("wafv2")
sns = boto3.client("sns")

LOG_GROUP = os.environ["WAF_LOG_GROUP"]
IP_SET_ID = os.environ["IP_SET_ID"]
IP_SET_NAME = os.environ["IP_SET_NAME"]
WAF_SCOPE = os.environ.get("WAF_SCOPE", "CLOUDFRONT")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
LOOKBACK_MINUTES = int(os.environ.get("LOOKBACK_MINUTES", "5"))


def lambda_handler(event, context):
    detail = event.get("detail", {})
    if detail.get("state", {}).get("value") != "ALARM":
        return {"skipped": True, "reason": "not ALARM"}

    ip = _top_blocked_ip()
    if not ip:
        return {"blocked": False, "reason": "no IP in WAF logs"}

    added = _add_ip_to_set(ip)
    if SNS_TOPIC_ARN and added:
        _notify(ip)

    return {"blocked": True, "ip": ip, "added": added}


def _top_blocked_ip():
    end = int(time.time())
    start = end - LOOKBACK_MINUTES * 60
    query = """
fields @timestamp, httpRequest.clientIp as ip, action
| filter action = "BLOCK" and ispresent(ip)
| stats count(*) as hits by ip
| sort hits desc
| limit 1
"""
    qid = logs.start_query(
        logGroupName=LOG_GROUP,
        startTime=start,
        endTime=end,
        queryString=query,
    )["queryId"]

    for _ in range(24):
        resp = logs.get_query_results(queryId=qid)
        status = resp["status"]
        if status == "Complete":
            rows = resp.get("results", [])
            if not rows:
                return None
            for field in rows[0]:
                if field["field"] == "ip":
                    return field["value"]
            return None
        if status in ("Failed", "Cancelled", "Timeout"):
            return None
        time.sleep(0.5)

    logs.stop_query(queryId=qid)
    return None


def _add_ip_to_set(ip: str) -> bool:
    cidr = ip if "/" in ip else f"{ip}/32"

    resp = wafv2.get_ip_set(Name=IP_SET_NAME, Scope=WAF_SCOPE, Id=IP_SET_ID)
    lock = resp["LockToken"]
    addrs = list(resp["IPSet"]["Addresses"])

    if cidr in addrs:
        return False

    addrs.append(cidr)
    wafv2.update_ip_set(
        Name=IP_SET_NAME,
        Scope=WAF_SCOPE,
        Id=IP_SET_ID,
        Addresses=addrs,
        LockToken=lock,
    )
    return True


def _notify(ip: str):
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject="[ACME IR] WAF attacker IP blocked",
        Message=(
            "Scenario: Low & Slow / WAF remediation\n"
            f"Blocked IP added to WAF IP set: {ip}\n"
            f"IP set: {IP_SET_NAME}\n"
        ),
    )
