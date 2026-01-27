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

# Cross-account domain setup:
# - Domain + Hosted Zone: default account (954800154782)
# - Infrastructure (Lambda, API GW, etc.): personal account (383757231925)
#
# Set enable_custom_domain=true to create certificates and custom domains
# DNS records must be created manually in the default account's hosted zone
enable_custom_domain = config.get_bool("enable_custom_domain") or False

domain_name = config.get("domain_name") or "footprintmaps.com"
api_subdomain = f"api.{domain_name}"

# Note: hosted_zone is in a DIFFERENT account, so we can't manage DNS records from here
# DNS records must be added manually or via a separate Pulumi stack in the default account
hosted_zone = None  # Cross-account - cannot access from here

# ACM Certificate for the domain (regional, for API Gateway)
# Note: DNS validation records must be added manually to the hosted zone in the default account
certificate = None
cert_validation = None

if enable_custom_domain:
    certificate = aws.acm.Certificate(
        resource_name("certificate"),
        domain_name=domain_name,
        subject_alternative_names=[f"*.{domain_name}"],
        validation_method="DNS",
        tags=common_tags,
    )

    # Export validation records for manual addition to default account's hosted zone
    export(
        "cert_validation_name",
        certificate.domain_validation_options[0].resource_record_name,
    )
    export(
        "cert_validation_type",
        certificate.domain_validation_options[0].resource_record_type,
    )
    export(
        "cert_validation_value",
        certificate.domain_validation_options[0].resource_record_value,
    )

    # Certificate validation - will succeed once DNS records are added to default account
    cert_validation = aws.acm.CertificateValidation(
        resource_name("cert-validation"),
        certificate_arn=certificate.arn,
    )

# =============================================================================
# API Gateway Custom Domain (api.footprintmaps.com)
# =============================================================================

api_domain = None
api_mapping = None

if enable_custom_domain and cert_validation:
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

    # Export API domain target for manual DNS record in default account
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

if enable_custom_domain:
    cloudfront_certificate = aws.acm.Certificate(
        resource_name("cf-certificate"),
        domain_name=domain_name,
        validation_method="DNS",
        tags=common_tags,
        opts=ResourceOptions(
            provider=aws.Provider("us-east-1-provider", region="us-east-1")
        ),
    )

    # Export CloudFront cert validation records for manual addition to default account
    export(
        "cf_cert_validation_name",
        cloudfront_certificate.domain_validation_options[0].resource_record_name,
    )
    export(
        "cf_cert_validation_type",
        cloudfront_certificate.domain_validation_options[0].resource_record_type,
    )
    export(
        "cf_cert_validation_value",
        cloudfront_certificate.domain_validation_options[0].resource_record_value,
    )

    cf_cert_validation = aws.acm.CertificateValidation(
        resource_name("cf-cert-validation"),
        certificate_arn=cloudfront_certificate.arn,
        opts=ResourceOptions(
            provider=aws.Provider("us-east-1-provider-validation", region="us-east-1")
        ),
    )

    # CloudFront distribution for marketing website
    website_distribution = aws.cloudfront.Distribution(
        resource_name("website-cdn"),
        enabled=True,
        is_ipv6_enabled=True,
        default_root_object="index.html",
        aliases=[domain_name],
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

    # Export CloudFront domain for manual DNS record in default account
    export("cloudfront_domain_name", website_distribution.domain_name)
    export("cloudfront_hosted_zone_id", website_distribution.hosted_zone_id)

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
    pulumi.log.info("=== MANUAL DNS SETUP REQUIRED ===")
    pulumi.log.info("Add these records to the hosted zone in the DEFAULT AWS account:")
    pulumi.log.info("See Pulumi outputs for cert_validation_* and cloudfront_* values")
else:
    pulumi.log.info("Custom domain DISABLED - using default AWS URLs")
    pulumi.log.info("Enable with: pulumi config set enable_custom_domain true")
