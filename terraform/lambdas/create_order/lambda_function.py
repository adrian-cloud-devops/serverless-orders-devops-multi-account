import json
import boto3
import os
from decimal import Decimal
import uuid

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

def lambda_handler(event, context):
    try:
        # --- Walidacja eventu ---
        if "body" not in event:
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "Missing request body"})
            }

        try:
            body = json.loads(event["body"])
        except json.JSONDecodeError:
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "Invalid JSON format"})
            }

        # --- Walidacja customerId ---
        if "customerId" not in body or not body["customerId"]:
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "Missing 'customerId'"})
            }

        # --- Walidacja totalAmount (czy naturalna liczba) ---
        if "totalAmount" not in body:
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "Missing 'totalAmount'"})
            }

        try:
            amount_value = int(body["totalAmount"])
            if amount_value <= 0:
                return {
                    "statusCode": 400,
                    "body": json.dumps({"message": "'totalAmount' must be a natural number > 0"})
                }
        except (ValueError, TypeError):
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "'totalAmount' must be a natural number"})
            }

        # --- Tworzenie zamówienia ---
        order_id = str(uuid.uuid4())

        item = {
            "orderId": order_id,
            "customerId": body["customerId"],
            "amount": Decimal(str(amount_value)),
            "status": "CREATED"
        }

        table = get_dynamodb_table()
        table.put_item(Item=item)

        return {
            "statusCode": 200,
            "body": json.dumps({
                "orderId": order_id,
                "status": "CREATED"
            })
        }

    except Exception as e:
        print("[ERROR]", str(e))
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Internal server error"})
        }
