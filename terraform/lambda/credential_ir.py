"""Scenario 3: CloudWatch Alarm → RotateSecret + SNS (credential IR)."""
import os

import boto3

secrets = boto3.client("secretsmanager")
sns = boto3.client("sns")

SECRET_ARN = os.environ["SECRET_ARN"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]


def lambda_handler(event, context):
    alarm_name = event.get("alarmData", {}).get("alarmName", "unknown-alarm")
    reason = (
        "Abnormal GetSecretValue pattern detected via CloudTrail metric "
        f"(alarm: {alarm_name})."
    )

    secrets.rotate_secret(SecretId=SECRET_ARN)

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject="[ACME IR] DB credential forced rotation",
        Message=(
            "Scenario 3 — Credential layer IR\n"
            f"{reason}\n"
            f"Action: RotateSecret executed\n"
            f"Secret: {SECRET_ARN}\n"
            "The RDS master password was rotated via Secrets Manager.\n"
        ),
    )

    return {"status": "rotated", "secret_arn": SECRET_ARN}
