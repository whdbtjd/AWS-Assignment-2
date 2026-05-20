"""Config 자동 수정: SG에서 0.0.0.0/0 (및 ::/0) → TCP 22 인바운드만 제거 (80/443 유지)."""

import json
import logging

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")

OPEN_CIDRS = {"0.0.0.0/0", "::/0"}


    return {"remediated": True, "securityGroupId": sg_id, "revoked": to_revoke}


def _resolve_sg_id(event):
    if isinstance(event, str):
        try:
            event = json.loads(event)
        except json.JSONDecodeError:
            return None
    if isinstance(event, dict):
        if event.get("GroupId"):
            return event["GroupId"]
        if isinstance(event.get("Payload"), dict) and event["Payload"].get("GroupId"):
            return event["Payload"]["GroupId"]
        invoking = event.get("invokingEvent")
        if invoking:
            if isinstance(invoking, str):
                invoking = json.loads(invoking)
            item = invoking.get("configurationItem") or invoking.get("configurationItemSummary") or {}
            return item.get("resourceId")
    return None


def lambda_handler(event, context):
    sg_id = _resolve_sg_id(event)
    if not sg_id or not str(sg_id).startswith("sg-"):
        logger.error("No security group id in event: %s", event)
        return {"remediated": False, "reason": "missing sg id"}

    sg = ec2.describe_security_groups(GroupIds=[sg_id])["SecurityGroups"][0]
    to_revoke = []

    for perm in sg.get("IpPermissions", []):
        if not _is_ssh(perm):
            continue
        bad_ipv4 = [r for r in perm.get("IpRanges", []) if r.get("CidrIp") in OPEN_CIDRS]
        bad_ipv6 = [r for r in perm.get("Ipv6Ranges", []) if r.get("CidrIpv6") in OPEN_CIDRS]
        if bad_ipv4 or bad_ipv6:
            entry = {
                "IpProtocol": perm["IpProtocol"],
                "FromPort": perm.get("FromPort"),
                "ToPort": perm.get("ToPort"),
            }
            if bad_ipv4:
                entry["IpRanges"] = [{"CidrIp": r["CidrIp"]} for r in bad_ipv4]
            if bad_ipv6:
                entry["Ipv6Ranges"] = [{"CidrIpv6": r["CidrIpv6"]} for r in bad_ipv6]
            to_revoke.append(entry)

    if not to_revoke:
        logger.info("No open SSH rules on %s", sg_id)
        return {"remediated": False, "securityGroupId": sg_id, "reason": "no matching rules"}

    ec2.revoke_security_group_ingress(GroupId=sg_id, IpPermissions=to_revoke)
    logger.info("Revoked open SSH ingress on %s: %s", sg_id, to_revoke)
    return {"remediated": True, "securityGroupId": sg_id, "revoked": to_revoke}


def _is_ssh(perm):
    if perm.get("IpProtocol") in ("tcp", 6, "6"):
        fp = perm.get("FromPort")
        tp = perm.get("ToPort")
        if fp is not None and tp is not None:
            return fp <= 22 <= tp
        return True
    return False
