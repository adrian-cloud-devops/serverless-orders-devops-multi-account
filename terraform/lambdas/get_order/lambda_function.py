import json
import boto3
import os
from decimal import Decimal

sts = boto3.client("sts")

def get_dynamodb_table():
    role_arn = os.environ["DATA_ACCESS_ROLE_ARN"]

    resp = sts.assume_role(
        RoleArn=role_arn,
        RoleSessionName="OrdersAppSession"
    )

    creds = resp["Credentials"]

    ddb = boto3.resource(
        "dynamodb",
        aws_access_key_id=creds["AccessKeyId"],
        aws_secret_access_key=creds["SecretAccessKey"],
        aws_session_token=creds["SessionToken"]
    )

    return ddb.Table("OrdersTable")

def to_serializable(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    return obj

def lambda_handler(event, context):

    #  TEST ALERTU — poza try/except
    order_id = event.get("pathParameters", {}).get("id")
    if order_id == "trigger-alarm":
        raise Exception("test alarm for get_order")

    try:
        # --- Walidacja pathParameters ---
        if "pathParameters" not in event or not event["pathParameters"]:
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "Missing path parameters"})
            }

        order_id = event["pathParameters"].get("id")
        if not order_id:
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "Missing 'id' in path"})
            }

        table = get_dynamodb_table()

        # --- Pobranie z DynamoDB ---
        resp = table.get_item(Key={"orderId": order_id})
        item = resp.get("Item")

        if not item:
            return {
                "statusCode": 404,
                "body": json.dumps({"message": "Order not found"})
            }

        return {
            "statusCode": 200,
            "body": json.dumps(item, default=to_serializable)
        }

    except Exception as e:
        print("[ERROR]", str(e))
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Internal server error"})
        }