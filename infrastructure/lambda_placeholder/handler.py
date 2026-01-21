import json
import os


def handler(event, context):
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
        },
        "body": json.dumps(
            {
                "message": "Skratch API is running",
                "environment": os.environ.get("ENVIRONMENT", "unknown"),
                "version": "0.1.0",
            }
        ),
    }
