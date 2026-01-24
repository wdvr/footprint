"""
Footprint Travel Tracker AWS Infrastructure

This Pulumi program defines the AWS infrastructure for the Footprint travel tracking application,
including DynamoDB tables, S3 buckets, Lambda functions, and API Gateway configuration.
"""

import json
import os

import pulumi
import pulumi_aws as aws
from pulumi import AssetArchive, Config, FileArchive, FileAsset, ResourceOptions, export

# Get configuration
config = Config()
environment = config.get("environment") or "dev"
app_name = config.get("app_name") or "footprint"
aws_region = aws.config.region or "us-east-1"

# Get AWS account ID for globally unique names
aws_account_id = aws.get_caller_identity().account_id


# Create resource name prefix
def resource_name(resource_type: str, include_account: bool = False) -> str:
    """Generate consistent resource names."""
    if include_account:
        return f"{app_name}-{resource_type}-{environment}-{aws_account_id}"
    return f"{app_name}-{resource_type}-{environment}"


# Tags to apply to all resources
common_tags = {
    "Environment": environment,
    "Application": app_name,
    "ManagedBy": "Pulumi",
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

# S3 bucket for geographic data storage (use account ID for globally unique name)
geo_data_bucket = aws.s3.Bucket(
    resource_name("geo-data"),
    bucket=resource_name("geo-data", include_account=True),
    tags=common_tags,
    opts=ResourceOptions(protect=environment == "prod"),
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
    assume_role_policy=json.dumps(
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {"Service": "lambda.amazonaws.com"},
                    "Action": "sts:AssumeRole",
                }
            ],
        }
    ),
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
    policy=dynamodb_table.arn.apply(
        lambda arn: json.dumps(
            {
                "Version": "2012-10-17",
                "Statement": [
                    {
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
                        "Resource": [arn, f"{arn}/index/*"],
                    }
                ],
            }
        )
    ),
)

# S3 access policy for Lambda
s3_policy = aws.iam.RolePolicy(
    resource_name("lambda-s3-policy"),
    role=lambda_role.id,
    policy=geo_data_bucket.arn.apply(
        lambda arn: json.dumps(
            {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Action": ["s3:GetObject", "s3:ListBucket"],
                        "Resource": [arn, f"{arn}/*"],
                    }
                ],
            }
        )
    ),
)

# =============================================================================
# Lambda Function
# =============================================================================

# Check if deployment package exists, otherwise use placeholder
lambda_package_path = os.path.join(os.path.dirname(__file__), "lambda_package.zip")

if os.path.exists(lambda_package_path):
    # Use the full FastAPI deployment package
    lambda_code = FileArchive(lambda_package_path)
    lambda_handler = "handler.handler"
    pulumi.log.info("Using FastAPI deployment package")
else:
    # Fall back to placeholder for initial setup
    pulumi.log.warn(
        "Lambda package not found, using placeholder. Run deploy_lambda.py first."
    )
    lambda_dir = os.path.join(os.path.dirname(__file__), "lambda_placeholder")
    os.makedirs(lambda_dir, exist_ok=True)
    lambda_file = os.path.join(lambda_dir, "handler.py")
    placeholder_code = """import json
import os

def handler(event, context):
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps({
            "message": "Footprint API placeholder - deploy FastAPI package",
            "environment": os.environ.get("ENVIRONMENT", "unknown"),
        })
    }
"""
    with open(lambda_file, "w") as f:
        f.write(placeholder_code)
    lambda_code = AssetArchive({"handler.py": FileAsset(lambda_file)})
    lambda_handler = "handler.handler"

# Lambda function
api_lambda = aws.lambda_.Function(
    resource_name("api"),
    name=resource_name("api"),
    role=lambda_role.arn,
    handler=lambda_handler,
    runtime="python3.11",
    code=lambda_code,
    timeout=30,
    memory_size=512,  # Increased for FastAPI
    environment=aws.lambda_.FunctionEnvironmentArgs(
        variables={
            "ENVIRONMENT": environment,
            "DYNAMODB_TABLE": dynamodb_table.name,
            "GEO_DATA_BUCKET": geo_data_bucket.bucket,
            "JWT_SECRET": config.get_secret("jwt_secret")
            or "dev-secret-change-in-production",
            "APPLE_BUNDLE_ID": "com.footprint.app",
            # Google OAuth (for Gmail/Calendar import)
            "GOOGLE_CLIENT_ID": config.get("google_client_id") or "",
            "GOOGLE_CLIENT_SECRET": config.get_secret("google_client_secret") or "",
            "GOOGLE_REDIRECT_URI": "https://footprintmaps.com/api/import/google/oauth/callback",
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
# Custom Domain (footprintmaps.com)
# =============================================================================

domain_name = config.get("domain_name") or "footprintmaps.com"

# Get the hosted zone (created automatically with domain registration)
hosted_zone = aws.route53.get_zone(name=domain_name)

# ACM Certificate for the domain
certificate = aws.acm.Certificate(
    resource_name("certificate"),
    domain_name=domain_name,
    subject_alternative_names=[f"*.{domain_name}"],
    validation_method="DNS",
    tags=common_tags,
)

# DNS validation record (same record validates both domain and wildcard)
cert_validation_record = aws.route53.Record(
    resource_name("cert-validation-record"),
    zone_id=hosted_zone.zone_id,
    name=certificate.domain_validation_options[0].resource_record_name,
    type=certificate.domain_validation_options[0].resource_record_type,
    records=[certificate.domain_validation_options[0].resource_record_value],
    ttl=300,
    allow_overwrite=True,
    opts=ResourceOptions(depends_on=[certificate]),
)

# Wait for certificate validation
cert_validation = aws.acm.CertificateValidation(
    resource_name("cert-validation"),
    certificate_arn=certificate.arn,
    validation_record_fqdns=[cert_validation_record.fqdn],
)

# API Gateway custom domain
api_domain = aws.apigatewayv2.DomainName(
    resource_name("api-domain"),
    domain_name=domain_name,
    domain_name_configuration=aws.apigatewayv2.DomainNameDomainNameConfigurationArgs(
        certificate_arn=cert_validation.certificate_arn,
        endpoint_type="REGIONAL",
        security_policy="TLS_1_2",
    ),
    tags=common_tags,
)

# API mapping to connect domain to API
api_mapping = aws.apigatewayv2.ApiMapping(
    resource_name("api-mapping"),
    api_id=api_gateway.id,
    domain_name=api_domain.domain_name,
    stage=api_stage.name,
    api_mapping_key="api",  # https://footprintmaps.com/api/...
)

# Route53 A record pointing to API Gateway
api_dns_record = aws.route53.Record(
    resource_name("api-dns"),
    zone_id=hosted_zone.zone_id,
    name=domain_name,
    type="A",
    aliases=[
        aws.route53.RecordAliasArgs(
            name=api_domain.domain_name_configuration.target_domain_name,
            zone_id=api_domain.domain_name_configuration.hosted_zone_id,
            evaluate_target_health=False,
        )
    ],
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
pulumi.log.info(f"Deploying Footprint infrastructure for environment: {environment}")
pulumi.log.info(f"DynamoDB Table: {resource_name('table')}")
pulumi.log.info("API Gateway will be available at the exported api_url")
