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
    timeout=600,  # 10 minutes for import processing
    memory_size=512,  # Increased for FastAPI
    environment=aws.lambda_.FunctionEnvironmentArgs(
        variables={
            "ENVIRONMENT": environment,
            "DYNAMODB_TABLE": dynamodb_table.name,
            "GEO_DATA_BUCKET": geo_data_bucket.bucket,
            "JWT_SECRET": config.get_secret("jwt_secret")
            or "dev-secret-change-in-production",
            "APPLE_BUNDLE_ID": "com.wouterdevriendt.footprint",
            # Google OAuth for sign-in (iOS client ID, no secret needed)
            "GOOGLE_CLIENT_ID": config.get("google_client_id") or "",
            # Google OAuth for import (Web App client ID with secret)
            "GOOGLE_IMPORT_CLIENT_ID": config.get("google_import_client_id") or "",
            "GOOGLE_IMPORT_CLIENT_SECRET": config.get_secret(
                "google_import_client_secret"
            )
            or "",
            "GOOGLE_REDIRECT_URI": "https://api.footprintmaps.com/import/google/oauth/callback",
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

# Domain configuration - everything in one AWS account
# Set enable_custom_domain=true to create hosted zone, certificates, and custom domains
enable_custom_domain = config.get_bool("enable_custom_domain") or False

domain_name = config.get("domain_name") or "footprintmaps.com"
api_subdomain = f"api.{domain_name}"

# Route53 Hosted Zone for the domain
# Note: Domain registration must be done via AWS Console or CLI first
# Once registered, this creates the hosted zone and manages DNS records
hosted_zone = None
certificate = None
cert_validation = None
cert_validation_records = []

if enable_custom_domain:
    # Create the Route53 Hosted Zone
    hosted_zone = aws.route53.Zone(
        resource_name("hosted-zone"),
        name=domain_name,
        comment=f"Hosted zone for {domain_name} - managed by Pulumi",
        tags=common_tags,
    )

    # Export nameservers for domain registration
    export("nameservers", hosted_zone.name_servers)
    export("hosted_zone_id", hosted_zone.zone_id)

    # ACM Certificate for the domain (regional, for API Gateway)
    certificate = aws.acm.Certificate(
        resource_name("certificate"),
        domain_name=domain_name,
        subject_alternative_names=[f"*.{domain_name}"],
        validation_method="DNS",
        tags=common_tags,
    )

    # Create DNS validation records in Route53
    # Using dynamic indexing for domain validation options
    # allow_overwrite=True handles case where CloudFront cert uses same validation record
    cert_validation_records = []
    for i in range(2):  # Main domain + wildcard
        record = aws.route53.Record(
            f"{resource_name('cert-validation')}-{i}",
            zone_id=hosted_zone.zone_id,
            name=certificate.domain_validation_options[i].resource_record_name,
            type=certificate.domain_validation_options[i].resource_record_type,
            records=[certificate.domain_validation_options[i].resource_record_value],
            ttl=300,
            allow_overwrite=True,
        )
        cert_validation_records.append(record)

    # Certificate validation - waits for DNS records to propagate
    cert_validation = aws.acm.CertificateValidation(
        resource_name("cert-validation"),
        certificate_arn=certificate.arn,
        validation_record_fqdns=[r.fqdn for r in cert_validation_records],
    )

# =============================================================================
# API Gateway Custom Domain (api.footprintmaps.com)
# =============================================================================

api_domain = None
api_mapping = None
api_dns_record = None

if enable_custom_domain and cert_validation and hosted_zone:
    # API Gateway custom domain - now on api subdomain
    api_domain = aws.apigatewayv2.DomainName(
        resource_name("api-domain"),
        domain_name=api_subdomain,
        domain_name_configuration=aws.apigatewayv2.DomainNameDomainNameConfigurationArgs(
            certificate_arn=cert_validation.certificate_arn,
            endpoint_type="REGIONAL",
            security_policy="TLS_1_2",
        ),
        tags=common_tags,
    )

    # API mapping to connect domain to API (no path prefix needed now)
    api_mapping = aws.apigatewayv2.ApiMapping(
        resource_name("api-mapping"),
        api_id=api_gateway.id,
        domain_name=api_domain.domain_name,
        stage=api_stage.name,
        # No api_mapping_key - API is at root of api.footprintmaps.com
    )

    # Create DNS A record (alias) for api.footprintmaps.com
    api_dns_record = aws.route53.Record(
        resource_name("api-dns"),
        zone_id=hosted_zone.zone_id,
        name=api_subdomain,
        type="A",
        aliases=[
            aws.route53.RecordAliasArgs(
                name=api_domain.domain_name_configuration.target_domain_name,
                zone_id=api_domain.domain_name_configuration.hosted_zone_id,
                evaluate_target_health=False,
            )
        ],
    )

    # Export API domain info
    export("api_domain_target", api_domain.domain_name_configuration.target_domain_name)
    export(
        "api_domain_hosted_zone_id", api_domain.domain_name_configuration.hosted_zone_id
    )

# =============================================================================
# Marketing Website (footprintmaps.com) - S3 + CloudFront
# =============================================================================

# S3 bucket for website static files
website_bucket = aws.s3.BucketV2(
    resource_name("website"),
    bucket=resource_name("website", include_account=True),
    tags=common_tags,
)

# Website bucket configuration
website_bucket_website = aws.s3.BucketWebsiteConfigurationV2(
    resource_name("website-config"),
    bucket=website_bucket.id,
    index_document=aws.s3.BucketWebsiteConfigurationV2IndexDocumentArgs(
        suffix="index.html",
    ),
    error_document=aws.s3.BucketWebsiteConfigurationV2ErrorDocumentArgs(
        key="index.html",  # SPA fallback
    ),
)

# Block public access - CloudFront will use OAC
website_bucket_public_access_block = aws.s3.BucketPublicAccessBlock(
    resource_name("website-pab"),
    bucket=website_bucket.id,
    block_public_acls=True,
    block_public_policy=True,
    ignore_public_acls=True,
    restrict_public_buckets=True,
)

# CloudFront Origin Access Control for S3
website_oac = aws.cloudfront.OriginAccessControl(
    resource_name("website-oac"),
    name=resource_name("website-oac"),
    origin_access_control_origin_type="s3",
    signing_behavior="always",
    signing_protocol="sigv4",
)

# ACM Certificate for CloudFront (must be in us-east-1)
# Note: Using the same certificate since we're already in us-east-1
cloudfront_certificate = None
cf_cert_validation = None
website_distribution = None
website_bucket_policy = None

# Create us-east-1 provider for CloudFront certificate (CloudFront requires us-east-1)
us_east_1_provider = aws.Provider("us-east-1-provider", region="us-east-1")

if enable_custom_domain and hosted_zone:
    cloudfront_certificate = aws.acm.Certificate(
        resource_name("cf-certificate"),
        domain_name=domain_name,
        subject_alternative_names=[f"www.{domain_name}"],
        validation_method="DNS",
        tags=common_tags,
        opts=ResourceOptions(provider=us_east_1_provider),
    )

    # Create DNS validation records for CloudFront certificate in Route53
    # allow_overwrite=True handles case where regional cert uses same validation record
    cf_cert_validation_records = []
    for i in range(2):  # Main domain + www subdomain
        record = aws.route53.Record(
            f"{resource_name('cf-cert-validation')}-{i}",
            zone_id=hosted_zone.zone_id,
            name=cloudfront_certificate.domain_validation_options[
                i
            ].resource_record_name,
            type=cloudfront_certificate.domain_validation_options[
                i
            ].resource_record_type,
            records=[
                cloudfront_certificate.domain_validation_options[
                    i
                ].resource_record_value
            ],
            ttl=300,
            allow_overwrite=True,
        )
        cf_cert_validation_records.append(record)

    cf_cert_validation = aws.acm.CertificateValidation(
        resource_name("cf-cert-validation"),
        certificate_arn=cloudfront_certificate.arn,
        validation_record_fqdns=[r.fqdn for r in cf_cert_validation_records],
        opts=ResourceOptions(provider=us_east_1_provider),
    )

    # CloudFront distribution for marketing website
    website_distribution = aws.cloudfront.Distribution(
        resource_name("website-cdn"),
        enabled=True,
        is_ipv6_enabled=True,
        default_root_object="index.html",
        aliases=[domain_name, f"www.{domain_name}"],
        origins=[
            aws.cloudfront.DistributionOriginArgs(
                domain_name=website_bucket.bucket_regional_domain_name,
                origin_id="S3Origin",
                origin_access_control_id=website_oac.id,
            ),
        ],
        default_cache_behavior=aws.cloudfront.DistributionDefaultCacheBehaviorArgs(
            allowed_methods=["GET", "HEAD", "OPTIONS"],
            cached_methods=["GET", "HEAD"],
            target_origin_id="S3Origin",
            viewer_protocol_policy="redirect-to-https",
            compress=True,
            forwarded_values=aws.cloudfront.DistributionDefaultCacheBehaviorForwardedValuesArgs(
                query_string=False,
                cookies=aws.cloudfront.DistributionDefaultCacheBehaviorForwardedValuesCookiesArgs(
                    forward="none",
                ),
            ),
            min_ttl=0,
            default_ttl=86400,
            max_ttl=31536000,
        ),
        custom_error_responses=[
            # SPA routing - return index.html for 404s
            aws.cloudfront.DistributionCustomErrorResponseArgs(
                error_code=404,
                response_code=200,
                response_page_path="/index.html",
            ),
            aws.cloudfront.DistributionCustomErrorResponseArgs(
                error_code=403,
                response_code=200,
                response_page_path="/index.html",
            ),
        ],
        restrictions=aws.cloudfront.DistributionRestrictionsArgs(
            geo_restriction=aws.cloudfront.DistributionRestrictionsGeoRestrictionArgs(
                restriction_type="none",
            ),
        ),
        viewer_certificate=aws.cloudfront.DistributionViewerCertificateArgs(
            acm_certificate_arn=cf_cert_validation.certificate_arn,
            ssl_support_method="sni-only",
            minimum_protocol_version="TLSv1.2_2021",
        ),
        tags=common_tags,
    )

    # S3 bucket policy to allow CloudFront access
    website_bucket_policy = aws.s3.BucketPolicy(
        resource_name("website-policy"),
        bucket=website_bucket.id,
        policy=pulumi.Output.all(website_bucket.arn, website_distribution.arn).apply(
            lambda args: json.dumps(
                {
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Sid": "AllowCloudFrontServicePrincipal",
                            "Effect": "Allow",
                            "Principal": {"Service": "cloudfront.amazonaws.com"},
                            "Action": "s3:GetObject",
                            "Resource": f"{args[0]}/*",
                            "Condition": {"StringEquals": {"AWS:SourceArn": args[1]}},
                        }
                    ],
                }
            )
        ),
    )

    # Create DNS A record (alias) for footprintmaps.com -> CloudFront
    if hosted_zone:
        website_dns_record = aws.route53.Record(
            resource_name("website-dns"),
            zone_id=hosted_zone.zone_id,
            name=domain_name,
            type="A",
            aliases=[
                aws.route53.RecordAliasArgs(
                    name=website_distribution.domain_name,
                    zone_id=website_distribution.hosted_zone_id,
                    evaluate_target_health=False,
                )
            ],
        )

        # Also add www subdomain pointing to the same CloudFront distribution
        www_dns_record = aws.route53.Record(
            resource_name("www-dns"),
            zone_id=hosted_zone.zone_id,
            name=f"www.{domain_name}",
            type="A",
            aliases=[
                aws.route53.RecordAliasArgs(
                    name=website_distribution.domain_name,
                    zone_id=website_distribution.hosted_zone_id,
                    evaluate_target_health=False,
                )
            ],
        )

    # Export CloudFront domain info
    export("cloudfront_domain_name", website_distribution.domain_name)
    export("cloudfront_hosted_zone_id", website_distribution.hosted_zone_id)

# =============================================================================
# SES Email Forwarding (support@footprintmaps.com -> Gmail)
# =============================================================================

# S3 bucket for storing incoming emails
email_bucket = aws.s3.BucketV2(
    resource_name("email"),
    bucket=resource_name("email", include_account=True),
    tags=common_tags,
)

# Lifecycle policy to delete old emails after 30 days
email_bucket_lifecycle = aws.s3.BucketLifecycleConfigurationV2(
    resource_name("email-lifecycle"),
    bucket=email_bucket.id,
    rules=[
        aws.s3.BucketLifecycleConfigurationV2RuleArgs(
            id="delete-old-emails",
            status="Enabled",
            expiration=aws.s3.BucketLifecycleConfigurationV2RuleExpirationArgs(
                days=30,
            ),
        ),
    ],
)

# S3 bucket policy to allow SES to write emails
email_bucket_policy = aws.s3.BucketPolicy(
    resource_name("email-policy"),
    bucket=email_bucket.id,
    policy=email_bucket.arn.apply(
        lambda arn: json.dumps(
            {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Sid": "AllowSESPuts",
                        "Effect": "Allow",
                        "Principal": {"Service": "ses.amazonaws.com"},
                        "Action": "s3:PutObject",
                        "Resource": f"{arn}/*",
                        "Condition": {
                            "StringEquals": {"AWS:SourceAccount": aws_account_id}
                        },
                    }
                ],
            }
        )
    ),
)

# Lambda function for email forwarding
email_forwarder_code = """
import boto3
import email
import os
import re
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication

s3 = boto3.client('s3')
ses = boto3.client('ses')

FORWARD_TO = os.environ['FORWARD_TO']
VERIFIED_EMAIL = os.environ['VERIFIED_EMAIL']

def handler(event, context):
    # Get the email from S3
    record = event['Records'][0]
    bucket = record['ses']['receipt']['action']['bucketName']
    key = record['ses']['receipt']['action']['objectKey']

    # Fetch email from S3
    response = s3.get_object(Bucket=bucket, Key=key)
    raw_email = response['Body'].read()

    # Parse the email
    msg = email.message_from_bytes(raw_email)

    # Create forwarded email
    forward_msg = MIMEMultipart()
    forward_msg['From'] = VERIFIED_EMAIL
    forward_msg['To'] = FORWARD_TO
    forward_msg['Subject'] = f"[Footprint] {msg['Subject']}"
    forward_msg['Reply-To'] = msg['From']

    # Add original headers as body prefix
    original_from = msg['From']
    original_to = msg['To']
    header_info = f"--- Forwarded from {original_from} to {original_to} ---\\n\\n"

    # Get body
    body = ""
    if msg.is_multipart():
        for part in msg.walk():
            content_type = part.get_content_type()
            if content_type == "text/plain":
                body = part.get_payload(decode=True).decode('utf-8', errors='replace')
                break
            elif content_type == "text/html" and not body:
                body = part.get_payload(decode=True).decode('utf-8', errors='replace')
    else:
        body = msg.get_payload(decode=True).decode('utf-8', errors='replace')

    forward_msg.attach(MIMEText(header_info + body, 'plain'))

    # Forward the email
    ses.send_raw_email(
        Source=VERIFIED_EMAIL,
        Destinations=[FORWARD_TO],
        RawMessage={'Data': forward_msg.as_string()}
    )

    print(f"Forwarded email from {original_from} to {FORWARD_TO}")
    return {'statusCode': 200}
"""

# Create the email forwarder Lambda
email_forwarder_lambda_role = aws.iam.Role(
    resource_name("email-forwarder-role"),
    name=resource_name("email-forwarder-role"),
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

# Lambda basic execution
aws.iam.RolePolicyAttachment(
    resource_name("email-forwarder-basic"),
    role=email_forwarder_lambda_role.name,
    policy_arn="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
)

# S3 and SES permissions for email forwarder
email_forwarder_policy = aws.iam.RolePolicy(
    resource_name("email-forwarder-policy"),
    role=email_forwarder_lambda_role.id,
    policy=email_bucket.arn.apply(
        lambda arn: json.dumps(
            {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Action": ["s3:GetObject"],
                        "Resource": f"{arn}/*",
                    },
                    {
                        "Effect": "Allow",
                        "Action": ["ses:SendRawEmail", "ses:SendEmail"],
                        "Resource": "*",
                    },
                ],
            }
        )
    ),
)

# Write Lambda code to file
email_forwarder_dir = os.path.join(os.path.dirname(__file__), "lambda_placeholder")
os.makedirs(email_forwarder_dir, exist_ok=True)
email_forwarder_file = os.path.join(email_forwarder_dir, "email_forwarder.py")
with open(email_forwarder_file, "w") as f:
    f.write(email_forwarder_code)

email_forwarder_lambda = aws.lambda_.Function(
    resource_name("email-forwarder"),
    name=resource_name("email-forwarder"),
    role=email_forwarder_lambda_role.arn,
    handler="email_forwarder.handler",
    runtime="python3.11",
    code=AssetArchive({"email_forwarder.py": FileAsset(email_forwarder_file)}),
    timeout=30,
    memory_size=128,
    environment=aws.lambda_.FunctionEnvironmentArgs(
        variables={
            "FORWARD_TO": "wouterdevriendt@gmail.com",
            "VERIFIED_EMAIL": f"noreply@{domain_name}",
        }
    ),
    tags=common_tags,
)

# Allow SES to invoke the Lambda
email_forwarder_permission = aws.lambda_.Permission(
    resource_name("email-forwarder-permission"),
    action="lambda:InvokeFunction",
    function=email_forwarder_lambda.name,
    principal="ses.amazonaws.com",
    source_account=aws_account_id,
)

# SES Domain Identity (verify domain for sending/receiving)
ses_domain_identity = None
ses_domain_dkim = None
ses_receipt_rule_set = None
ses_receipt_rule = None
mx_record = None

if enable_custom_domain and hosted_zone:
    # Verify domain in SES
    ses_domain_identity = aws.ses.DomainIdentity(
        resource_name("ses-domain"),
        domain=domain_name,
    )

    # DKIM for better deliverability
    ses_domain_dkim = aws.ses.DomainDkim(
        resource_name("ses-dkim"),
        domain=domain_name,
    )

    # Create DKIM DNS records
    for i in range(3):
        aws.route53.Record(
            f"{resource_name('ses-dkim-record')}-{i}",
            zone_id=hosted_zone.zone_id,
            name=ses_domain_dkim.dkim_tokens[i].apply(
                lambda t: f"{t}._domainkey.{domain_name}"
            ),
            type="CNAME",
            ttl=300,
            records=[
                ses_domain_dkim.dkim_tokens[i].apply(
                    lambda t: f"{t}.dkim.amazonses.com"
                )
            ],
        )

    # SES domain verification TXT record
    aws.route53.Record(
        resource_name("ses-verification"),
        zone_id=hosted_zone.zone_id,
        name=f"_amazonses.{domain_name}",
        type="TXT",
        ttl=300,
        records=[ses_domain_identity.verification_token],
    )

    # MX record for receiving email
    mx_record = aws.route53.Record(
        resource_name("mx-record"),
        zone_id=hosted_zone.zone_id,
        name=domain_name,
        type="MX",
        ttl=300,
        records=["10 inbound-smtp.us-east-1.amazonaws.com"],
    )

    # SES Receipt Rule Set
    ses_receipt_rule_set = aws.ses.ReceiptRuleSet(
        resource_name("ses-ruleset"),
        rule_set_name=resource_name("ses-ruleset"),
    )

    # Activate the rule set
    aws.ses.ActiveReceiptRuleSet(
        resource_name("ses-active-ruleset"),
        rule_set_name=ses_receipt_rule_set.rule_set_name,
    )

    # SES Receipt Rule for support@
    ses_receipt_rule = aws.ses.ReceiptRule(
        resource_name("ses-rule-support"),
        rule_set_name=ses_receipt_rule_set.rule_set_name,
        name="forward-support",
        recipients=[f"support@{domain_name}"],
        enabled=True,
        scan_enabled=True,
        s3_actions=[
            aws.ses.ReceiptRuleS3ActionArgs(
                bucket_name=email_bucket.bucket,
                position=1,
            ),
        ],
        lambda_actions=[
            aws.ses.ReceiptRuleLambdaActionArgs(
                function_arn=email_forwarder_lambda.arn,
                invocation_type="Event",
                position=2,
            ),
        ],
    )

    pulumi.log.info(
        f"Email forwarding: support@{domain_name} -> wouterdevriendt@gmail.com"
    )
    export("email_bucket", email_bucket.bucket)

# =============================================================================
# Exports
# =============================================================================

# Core infrastructure exports
export("dynamodb_table_name", dynamodb_table.name)
export("dynamodb_table_arn", dynamodb_table.arn)
export("geo_data_bucket_name", geo_data_bucket.bucket)
export("geo_data_bucket_arn", geo_data_bucket.arn)
export("lambda_function_name", api_lambda.name)
export("lambda_function_arn", api_lambda.arn)
export("api_gateway_id", api_gateway.id)
export("api_url", api_stage.invoke_url)
export("website_bucket_name", website_bucket.bucket)
export("environment", environment)
export("app_name", app_name)
export("custom_domain_enabled", enable_custom_domain)

# Domain-dependent exports (only when custom domain is enabled)
if enable_custom_domain and website_distribution:
    export("api_domain_url", pulumi.Output.concat("https://", api_subdomain))
    export("website_url", pulumi.Output.concat("https://", domain_name))
    export("cloudfront_distribution_id", website_distribution.id)
else:
    export("api_domain_url", api_stage.invoke_url)  # Use API Gateway URL directly
    export(
        "website_url",
        website_bucket.website_endpoint.apply(lambda e: f"http://{e}" if e else "N/A"),
    )

# Output deployment information
pulumi.log.info(f"Deploying Footprint infrastructure for environment: {environment}")
pulumi.log.info(f"DynamoDB Table: {resource_name('table')}")
if enable_custom_domain:
    pulumi.log.info(f"API will be available at: https://{api_subdomain}")
    pulumi.log.info(f"Website will be available at: https://{domain_name}")
    pulumi.log.info("")
    pulumi.log.info("=== DOMAIN REGISTRATION NOTE ===")
    pulumi.log.info("If the domain is not yet registered:")
    pulumi.log.info(
        "1. Register domain via AWS Console: Route 53 > Registered domains > Register domain"
    )
    pulumi.log.info(
        "2. Update the domain's nameservers to use the hosted zone nameservers"
    )
    pulumi.log.info("   (see 'nameservers' output after deployment)")
    pulumi.log.info("DNS records for API and website are automatically configured.")
else:
    pulumi.log.info("Custom domain DISABLED - using default AWS URLs")
    pulumi.log.info("Enable with: pulumi config set enable_custom_domain true")
