"""GuardDuty finding → ALB TG deregister + quarantine SG (격리 실습)."""

import json
import os

import boto3

ec2 = boto3.client("ec2")
elbv2 = boto3.client("elbv2")
sns = boto3.client("sns")

TARGET_GROUP_ARN = os.environ["TARGET_GROUP_ARN"]
QUARANTINE_SG_ID = os.environ["QUARANTINE_SG_ID"]
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
ASG_NAME = os.environ.get("ASG_NAME", "")


def lambda_handler(event, context):
    detail = event.get("detail", event)
    instance_id = _instance_id_from_finding(detail)
    if not instance_id:
        return {"isolated": False, "reason": "no EC2 instance in finding"}

    if ASG_NAME and not _instance_in_asg(instance_id, ASG_NAME):
        return {
            "isolated": False,
            "reason": f"instance not in ASG {ASG_NAME}",
            "instanceId": instance_id,
        }

    actions = _isolate(instance_id)
    _notify(instance_id, detail, actions)
    return {"isolated": True, "instanceId": instance_id, "actions": actions}


def _instance_id_from_finding(detail):
    resource = detail.get("resource") or {}
    if resource.get("resourceType") != "Instance":
        return None
    inst = resource.get("instanceDetails") or {}
    return inst.get("instanceId")


def _instance_in_asg(instance_id, asg_name):
    tags = ec2.describe_tags(
        Filters=[
            {"Name": "resource-id", "Values": [instance_id]},
            {"Name": "key", "Values": ["aws:autoscaling:groupName"]},
        ],
    ).get("Tags", [])
    return any(t.get("Value") == asg_name for t in tags)


def _primary_eni(instance_id):
    reservations = ec2.describe_instances(InstanceIds=[instance_id])["Reservations"]
    instance = reservations[0]["Instances"][0]
    interfaces = instance.get("NetworkInterfaces", [])
    if not interfaces:
        raise ValueError(f"No ENI on instance {instance_id}")
    for eni in interfaces:
        if eni.get("Attachment", {}).get("DeviceIndex") == 0:
            return eni["NetworkInterfaceId"]
    return interfaces[0]["NetworkInterfaceId"]


def _isolate(instance_id):
    actions = []

    try:
        elbv2.deregister_targets(
            TargetGroupArn=TARGET_GROUP_ARN,
            Targets=[{"Id": instance_id}],
        )
        actions.append("deregistered_from_target_group")
    except elbv2.exceptions.InvalidTargetException:
        actions.append("target_not_in_group")
    except Exception as err:
        if "TargetNotInUse" in str(err) or "not in target" in str(err).lower():
            actions.append("target_not_in_group")
        else:
            raise

    eni_id = _primary_eni(instance_id)
    ec2.modify_network_interface_attribute(
        NetworkInterfaceId=eni_id,
        Groups=[QUARANTINE_SG_ID],
    )
    actions.append("quarantine_security_group_applied")

    ec2.create_tags(
        Resources=[instance_id],
        Tags=[{"Key": "IsolationStatus", "Value": "quarantined"}],
    )
    actions.append("tagged")

    return actions


def _notify(instance_id, detail, actions):
    if not SNS_TOPIC_ARN:
        return

    finding_type = detail.get("type", "unknown")
    severity = detail.get("severity", "n/a")
    title = detail.get("title", "")

    message = (
        "GuardDuty isolation (Scenario: compromised workload egress)\n"
        f"{'─' * 40}\n"
        f"InstanceId : {instance_id}\n"
        f"Type       : {finding_type}\n"
        f"Severity   : {severity}\n"
        f"Title      : {title}\n"
        f"Actions    : {', '.join(actions)}\n"
        "ALB traffic removed; quarantine SG applied (SSM egress 443 only).\n"
    )

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject="[ACME IR] GuardDuty EC2 isolated",
        Message=message,
    )
