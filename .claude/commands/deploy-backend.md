# Deploy Footprint Backend

The backend runs on AWS Lambda + DynamoDB, deployed via Pulumi.

## Via GitHub Actions (preferred)

```bash
# Deploy (runs on push to main)
gh workflow run "Infrastructure Deploy" --repo wdvr/footprint
```

## Via Pulumi (manual)

```bash
cd infrastructure
source ../venv/bin/activate  # or: python -m venv ../venv && pip install -r requirements.txt
pip install -r requirements.txt

# Preview changes
AWS_PROFILE=personal pulumi preview --stack dev

# Deploy
AWS_PROFILE=personal pulumi up --yes --stack dev
```

## Deploy Website

```bash
cd website
npm install && npm run build

# Sync to S3
aws s3 sync dist/ s3://footprint-website-dev-383757231925/ --delete --profile personal

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id E2FGGZI8WVD597 --paths "/*" --profile personal
```

## API Endpoints
- **Production**: https://api.footprintmaps.com
- **Website**: https://footprintmaps.com

## Notes
- AWS Account: `383757231925` (personal profile)
- AWS Region: `us-east-1`
- Always use `AWS_PROFILE=personal` (NOT default)
- DynamoDB: Single-table design with pk/sk keys
- Lambda: Python 3.11, 512MB, 30s timeout
