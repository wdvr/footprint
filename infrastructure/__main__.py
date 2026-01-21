"""
Skratch Travel Tracker AWS Infrastructure

This Pulumi program defines the AWS infrastructure for the Skratch travel tracking application,
including DynamoDB tables, S3 buckets, Lambda functions, and API Gateway configuration.
"""

import pulumi
from pulumi import Config, export, ResourceOptions, Output, AssetArchive, FileAsset
import pulumi_aws as aws
import json

# Get configuration
config = Config()
environment = config.get("environment") or "dev"
app_name = config.get("app_name") or "skratch"
aws_region = aws.config.region or "us-east-1"

# Create resource name prefix
def resource_name(resource_type: str) -> str:
    """Generate consistent resource names."""
    return f"{app_name}-{resource_type}-{environment}"

# Tags to apply to all resources
common_tags = {
    "Environment": environment,
    "Application": app_name,
    "ManagedBy": "Pulumi"
}

# =============================================================================
# DynamoDB - Single Table Design
# =============================================================================

dynamodb_table = aws.dynamodb.Table(
    resource_name("table"),
    name=resource_name("table"),
    billing_mode="PAY_PER_REQUEST",
    hash_key="pk",
    range_key="sk",
    attributes=[
        aws.dynamodb.TableAttributeArgs(name="pk", type="S"),
        aws.dynamodb.TableAttributeArgs(name="sk", type="S"),
        aws.dynamodb.TableAttributeArgs(name="gsi1pk", type="S"),
        aws.dynamodb.TableAttributeArgs(name="gsi1sk", type="S"),
    ],
    global_secondary_indexes=[
        aws.dynamodb.TableGlobalSecondaryIndexArgs(
            name="gsi1",
            hash_key="gsi1pk",
            range_key="gsi1sk",
            projection_type="ALL",
        ),
    ],
    ttl=aws.dynamodb.TableTtlArgs(
        attribute_name="ttl",
        enabled=True,
    ),
    point_in_time_recovery=aws.dynamodb.TablePointInTimeRecoveryArgs(
        enabled=environment == "prod",
    ),
    tags=common_tags,
)

# =============================================================================
# S3 Buckets
# =============================================================================

# S3 bucket for geographic data storage
geo_data_bucket = aws.s3.Bucket(
    resource_name("geo-data"),
    bucket=resource_name("geo-data"),
    tags=common_tags,
    opts=ResourceOptions(protect=environment == "prod")
)

# Block public access to the geo data bucket
geo_data_bucket_public_access_block = aws.s3.BucketPublicAccessBlock(
    f"{resource_name('geo-data')}-pab",
    bucket=geo_data_bucket.id,
    block_public_acls=True,
    block_public_policy=True,
    ignore_public_acls=True,
    restrict_public_buckets=True,
)

# Enable CORS for geo data bucket (needed for map tile fetching)
geo_data_bucket_cors = aws.s3.BucketCorsConfigurationV2(
    f"{resource_name('geo-data')}-cors",
    bucket=geo_data_bucket.id,
    cors_rules=[
        aws.s3.BucketCorsConfigurationV2CorsRuleArgs(
            allowed_headers=["*"],
            allowed_methods=["GET"],
            allowed_origins=["*"],  # Will restrict in production
            max_age_seconds=3600,
        )
    ],
)

# =============================================================================
# IAM Roles and Policies
# =============================================================================

# Lambda execution role
lambda_role = aws.iam.Role(
    resource_name("lambda-role"),
    name=resource_name("lambda-role"),
    assume_role_policy=json.dumps({
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "lambda.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }),
    tags=common_tags,
)

# Lambda basic execution policy attachment
lambda_basic_execution = aws.iam.RolePolicyAttachment(
    resource_name("lambda-basic-execution"),
    role=lambda_role.name,
    policy_arn="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
)

# DynamoDB access policy for Lambda
dynamodb_policy = aws.iam.RolePolicy(
    resource_name("lambda-dynamodb-policy"),
    role=lambda_role.id,
    policy=dynamodb_table.arn.apply(lambda arn: json.dumps({
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem",
                "dynamodb:DeleteItem",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:BatchGetItem",
                "dynamodb:BatchWriteItem",
            ],
            "Resource": [arn, f"{arn}/index/*"]
        }]
    })),
)

# S3 access policy for Lambda
s3_policy = aws.iam.RolePolicy(
    resource_name("lambda-s3-policy"),
    role=lambda_role.id,
    policy=geo_data_bucket.arn.apply(lambda arn: json.dumps({
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": ["s3:GetObject", "s3:ListBucket"],
            "Resource": [arn, f"{arn}/*"]
        }]
    })),
)

# =============================================================================
# Lambda Function
# =============================================================================

# Create a simple handler for initial deployment
lambda_code = """import json
import os

def handler(event, context):
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        'body': json.dumps({
            'message': 'Skratch API is running',
            'environment': os.environ.get('ENVIRONMENT', 'unknown'),
            'version': '0.1.0'
        })
    }
"""

# Write Lambda code to a file
import os
lambda_dir = os.path.join(os.path.dirname(__file__), "lambda_placeholder")
os.makedirs(lambda_dir, exist_ok=True)
lambda_file = os.path.join(lambda_dir, "handler.py")
with open(lambda_file, "w") as f:
    f.write(lambda_code)

# Lambda function
api_lambda = aws.lambda_.Function(
    resource_name("api"),
    name=resource_name("api"),
    role=lambda_role.arn,
    handler="handler.handler",
    runtime="python3.11",
    code=AssetArchive({"handler.py": FileAsset(lambda_file)}),
    timeout=30,
    memory_size=256,
    environment=aws.lambda_.FunctionEnvironmentArgs(
        variables={
            "ENVIRONMENT": environment,
            "DYNAMODB_TABLE": dynamodb_table.name,
            "GEO_DATA_BUCKET": geo_data_bucket.bucket,
        }
    ),
    tags=common_tags,
)

# =============================================================================
# API Gateway
# =============================================================================

# HTTP API (API Gateway v2)
api_gateway = aws.apigatewayv2.Api(
    resource_name("api-gateway"),
    name=resource_name("api"),
    protocol_type="HTTP",
    cors_configuration=aws.apigatewayv2.ApiCorsConfigurationArgs(
        allow_headers=["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key"],
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_origins=["*"],  # Will restrict in production
        max_age=3600,
    ),
    tags=common_tags,
)

# Lambda integration
lambda_integration = aws.apigatewayv2.Integration(
    resource_name("lambda-integration"),
    api_id=api_gateway.id,
    integration_type="AWS_PROXY",
    integration_uri=api_lambda.invoke_arn,
    integration_method="POST",
    payload_format_version="2.0",
)

# Default route
default_route = aws.apigatewayv2.Route(
    resource_name("default-route"),
    api_id=api_gateway.id,
    route_key="$default",
    target=lambda_integration.id.apply(lambda id: f"integrations/{id}"),
)

# API stage
api_stage = aws.apigatewayv2.Stage(
    resource_name("api-stage"),
    api_id=api_gateway.id,
    name=environment,
    auto_deploy=True,
    tags=common_tags,
)

# Lambda permission for API Gateway
api_gateway_permission = aws.lambda_.Permission(
    resource_name("api-gateway-permission"),
    action="lambda:InvokeFunction",
    function=api_lambda.name,
    principal="apigateway.amazonaws.com",
    source_arn=api_gateway.execution_arn.apply(lambda arn: f"{arn}/*/*"),
)

# =============================================================================
# Exports
# =============================================================================

export("dynamodb_table_name", dynamodb_table.name)
export("dynamodb_table_arn", dynamodb_table.arn)
export("geo_data_bucket_name", geo_data_bucket.bucket)
export("geo_data_bucket_arn", geo_data_bucket.arn)
export("lambda_function_name", api_lambda.name)
export("lambda_function_arn", api_lambda.arn)
export("api_gateway_id", api_gateway.id)
export("api_url", api_stage.invoke_url)
export("environment", environment)
export("app_name", app_name)

# Output deployment information
pulumi.log.info(f"Deploying Skratch infrastructure for environment: {environment}")
pulumi.log.info(f"DynamoDB Table: {resource_name('table')}")
pulumi.log.info(f"API Gateway will be available at the exported api_url")
