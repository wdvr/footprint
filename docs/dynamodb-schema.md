# DynamoDB Schema Architecture for Skratch Travel Tracker

## Schema Design Philosophy

**Single-table design** with optimized access patterns for offline-first sync architecture. This approach minimizes DynamoDB costs, improves performance, and simplifies data management for mobile applications.

## Table Structure

### Primary Table: `skratch-data-{environment}`

**Partition Key (PK)**: String
**Sort Key (SK)**: String
**GSI1PK**: String (Global Secondary Index 1 Partition Key)
**GSI1SK**: String (Global Secondary Index 1 Sort Key)
**GSI2PK**: String (Global Secondary Index 2 Partition Key)
**GSI2SK**: String (Global Secondary Index 2 Sort Key)

## Entity Types & Access Patterns

### 1. User Profiles

```
PK: USER#{user_id}
SK: PROFILE
GSI1PK: AUTH#{auth_provider}#{auth_provider_id}
GSI1SK: USER#{user_id}
GSI2PK: EMAIL#{email} (if provided)
GSI2SK: USER#{user_id}

Data Attributes:
- user_id: String
- auth_provider: String (apple/email)
- auth_provider_id: String
- email: String (optional)
- display_name: String (optional)
- profile_picture_url: String (optional)
- countries_visited: Number
- us_states_visited: Number
- canadian_provinces_visited: Number
- privacy_settings: Map
- notification_settings: Map
- created_at: String (ISO 8601)
- updated_at: String (ISO 8601)
- last_login_at: String (ISO 8601)
- sync_version: Number
- last_sync_at: String (ISO 8601)
- ttl: Number (optional for cleanup)
```

**Access Patterns:**
- Get user by ID: `PK = USER#{user_id}, SK = PROFILE`
- Find user by Apple ID: `GSI1PK = AUTH#apple#{apple_id}`
- Find user by email: `GSI2PK = EMAIL#{email}`

### 2. Visited Places

```
PK: USER#{user_id}
SK: VISIT#{region_type}#{region_code}#{timestamp_ms}
GSI1PK: REGION#{region_type}#{region_code}
GSI1SK: USER#{user_id}#{timestamp_ms}
GSI2PK: USER#{user_id}#{region_type}
GSI2SK: VISIT#{timestamp_ms}

Data Attributes:
- composite_key: String (user_id#region_type#region_code)
- user_id: String
- region_type: String (country/us_state/canadian_province)
- region_code: String (ISO codes)
- region_name: String
- visited_date: String (ISO 8601, optional)
- notes: String (optional, max 500 chars)
- marked_at: String (ISO 8601)
- marked_from_device: String
- sync_version: Number
- last_modified_at: String (ISO 8601)
- is_deleted: Boolean
- operation_id: String (for sync tracking)
```

**Access Patterns:**
- Get all visited places for user: `PK = USER#{user_id}, SK begins_with VISIT#`
- Get visited places by region type: `GSI2PK = USER#{user_id}#{region_type}`
- Find all visitors to a region: `GSI1PK = REGION#{region_type}#{region_code}`
- Get recent visits: `GSI2PK = USER#{user_id}#{region_type}, SK begins_with VISIT#`

### 3. Sync Operations

```
PK: SYNC#{user_id}
SK: OP#{timestamp_ms}#{operation_id}
GSI1PK: SYNC_STATUS#{status}
GSI1SK: TIMESTAMP#{timestamp_ms}
GSI2PK: USER#{user_id}#{device_id}
GSI2SK: OP#{timestamp_ms}

Data Attributes:
- operation_id: String (UUID)
- user_id: String
- device_id: String
- operation_type: String (create/update/delete/batch_create/etc.)
- entity_type: String (visited_place/user)
- entity_id: String
- entity_data: Map (JSON payload)
- client_version: Number
- server_version: Number (optional)
- client_timestamp: String (ISO 8601)
- server_timestamp: String (ISO 8601, optional)
- has_conflict: Boolean
- conflict_details: Map (optional)
- resolution_strategy: String (optional)
- is_processed: Boolean
- processing_error: String (optional)
- ttl: Number (cleanup after 30 days)
```

**Access Patterns:**
- Get pending operations for user: `PK = SYNC#{user_id}, SK begins_with OP#`
- Get operations by status: `GSI1PK = SYNC_STATUS#{status}`
- Get operations by device: `GSI2PK = USER#{user_id}#{device_id}`
- Cleanup old operations: TTL based on `ttl` attribute

### 4. Geographic Reference Data

```
PK: GEO#{region_type}
SK: REGION#{region_code}
GSI1PK: SEARCH#{region_type}
GSI1SK: NAME#{normalized_name}
GSI2PK: BOUNDS#{bbox_key}
GSI2SK: REGION#{region_code}

Data Attributes:
- region_code: String
- region_type: String
- name: String
- display_name: String
- normalized_name: String (lowercase, no spaces)
- continent_code: String (for countries)
- parent_region: String (state parent country)
- capital: String (optional)
- population: Number (optional)
- area_km2: Number (optional)
- bbox_north: Number
- bbox_south: Number
- bbox_east: Number
- bbox_west: Number
- center_lat: Number
- center_lon: Number
- boundary_data_url: String (S3 URL)
- boundary_simplified_url: String (S3 URL)
- data_version: String
- last_updated: String (ISO 8601)
```

**Access Patterns:**
- Get region by code: `PK = GEO#{region_type}, SK = REGION#{region_code}`
- Search regions by name: `GSI1PK = SEARCH#{region_type}, SK begins_with NAME#{partial_name}`
- Find regions by bounding box: `GSI2PK = BOUNDS#{bbox_key}`

### 5. User Statistics Cache

```
PK: USER#{user_id}
SK: STATS#{calculation_date}
GSI1PK: STATS_DATE#{calculation_date}
GSI1SK: USER#{user_id}

Data Attributes:
- user_id: String
- calculation_date: String (YYYY-MM-DD)
- countries_visited: Number
- countries_percentage: Number
- us_states_visited: Number
- us_states_percentage: Number
- canadian_provinces_visited: Number
- canadian_provinces_percentage: Number
- total_regions_visited: Number
- total_regions_percentage: Number
- continents_visited: List[String]
- recent_visits: List[Map] (last 10)
- travel_streak_days: Number
- calculated_at: String (ISO 8601)
- ttl: Number (refresh daily)
```

## Global Secondary Indexes

### GSI1: Authentication & Cross-Entity Queries
- **PK**: GSI1PK (AUTH#{provider}#{id}, REGION#{type}#{code}, etc.)
- **SK**: GSI1SK (USER#{id}, TIMESTAMP#{ts}, etc.)
- **Projection**: ALL
- **Use Cases**: User authentication, regional analytics, status-based queries

### GSI2: User-Centric & Temporal Queries
- **PK**: GSI2PK (USER#{id}#{type}, STATS_DATE#{date}, etc.)
- **SK**: GSI2SK (VISIT#{timestamp}, OP#{timestamp}, etc.)
- **Projection**: ALL
- **Use Cases**: User timeline, device-specific operations, time-based queries

## Performance Optimizations

### Partition Key Design
- **Users**: Distribute evenly across partitions using user_id hash
- **Geographic data**: Low-volume, read-heavy (cache friendly)
- **Sync operations**: Partitioned by user to avoid hot partitions
- **Statistics**: Cached daily to reduce computation overhead

### Query Patterns Efficiency

```python
# Example: Get all countries visited by user (single query)
response = dynamodb.query(
    KeyConditionExpression=Key('GSI2PK').eq(f'USER#{user_id}#country')
)

# Example: Get pending sync operations (single query)
response = dynamodb.query(
    KeyConditionExpression=Key('PK').eq(f'SYNC#{user_id}') &
                          Key('SK').begins_with('OP#')
)

# Example: Find user by Apple ID (single query)
response = dynamodb.query(
    IndexName='GSI1',
    KeyConditionExpression=Key('GSI1PK').eq(f'AUTH#apple#{apple_id}')
)
```

### Write Patterns for Sync

```python
# Atomic update with condition check for conflict detection
def update_visited_place(user_id, region_code, region_type, client_version, data):
    try:
        response = dynamodb.update_item(
            Key={
                'PK': f'USER#{user_id}',
                'SK': f'VISIT#{region_type}#{region_code}#{timestamp}'
            },
            UpdateExpression='SET #data = :data, sync_version = sync_version + :inc',
            ConditionExpression='sync_version = :expected_version',
            ExpressionAttributeNames={'#data': 'entity_data'},
            ExpressionAttributeValues={
                ':data': data,
                ':inc': 1,
                ':expected_version': client_version
            },
            ReturnValues='ALL_NEW'
        )
        return response
    except ClientError as e:
        if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
            # Handle sync conflict
            return handle_sync_conflict(user_id, region_code, region_type, data)
```

## Cost Optimization

### Expected Read/Write Patterns
- **Reads**: 80% (user queries, map data lookup)
- **Writes**: 20% (place marking, sync operations)

### Provisioned vs On-Demand
- **Recommendation**: On-demand for initial launch
- **Transition**: Switch to provisioned capacity after establishing patterns
- **Expected cost**: $5-15/month for 1K active users

### TTL Configuration
- **Sync operations**: 30-day TTL
- **Statistics cache**: 7-day TTL
- **Old user sessions**: 90-day TTL for inactive users

## Data Migration & Backup Strategy

### Backup Configuration
- **Point-in-time recovery**: Enabled
- **Cross-region backup**: Every 24 hours
- **Export to S3**: Weekly for analytics

### Schema Evolution
- **Versioning**: Use `schema_version` attribute
- **Migration**: Blue-green deployment with dual writes
- **Rollback**: Keep previous schema version for 30 days

## Security Considerations

### Access Control
- **IAM policies**: Least privilege for Lambda functions
- **VPC configuration**: Database in private subnets
- **Encryption**: At-rest and in-transit encryption enabled

### Data Protection
- **PII handling**: Hash emails for indexing
- **Data retention**: GDPR-compliant deletion policies
- **Audit logging**: CloudTrail integration for all operations

This schema design supports:
✅ Offline-first architecture
✅ Efficient sync conflict resolution
✅ Scalable to millions of users
✅ Cost-optimized access patterns
✅ GDPR compliance
✅ Real-time statistics calculation