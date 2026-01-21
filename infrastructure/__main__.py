"""
Skratch Travel Tracker AWS Infrastructure

This Pulumi program defines the AWS infrastructure for the Skratch travel tracking application,
including DynamoDB tables, S3 buckets, Lambda functions, and API Gateway configuration.
"""

import pulumi
from pulumi import Config, export, ResourceOptions
import pulumi_aws as aws

# Get configuration
config = Config()
environment = config.get("environment", "dev")
app_name = config.get("app_name", "skratch")

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

# Placeholder infrastructure - will be expanded in Phase 3
# For now, just create a simple S3 bucket to validate the pipeline

# S3 bucket for geographic data storage
geo_data_bucket = aws.s3.Bucket(
    resource_name("geo-data"),
    bucket=resource_name("geo-data"),
    tags=common_tags,
    opts=ResourceOptions(
        protect=False  # Allow deletion in dev environment
    )
)

# Block public access to the bucket
geo_data_bucket_public_access_block = aws.s3.BucketPublicAccessBlock(
    f"{resource_name('geo-data')}-pab",
    bucket=geo_data_bucket.id,
    block_public_acls=True,
    block_public_policy=True,
    ignore_public_acls=True,
    restrict_public_buckets=True
)

# Export important values
export("geo_data_bucket_name", geo_data_bucket.bucket)
export("geo_data_bucket_arn", geo_data_bucket.arn)
export("environment", environment)
export("app_name", app_name)

# Output deployment information
pulumi.log.info(f"Deploying Skratch infrastructure for environment: {environment}")
pulumi.log.info("This is a basic infrastructure setup for CI/CD validation.")
pulumi.log.info("Full infrastructure will be implemented in Phase 3.")