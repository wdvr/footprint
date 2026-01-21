# Skratch Travel Tracker REST API Specification

## API Design Philosophy

**Offline-first, mobile-optimized REST API** designed for efficient sync operations, minimal data transfer, and robust conflict resolution. All endpoints support batch operations and optimistic locking for seamless offline-to-online synchronization.

**Base URL**: `https://api.skratch.travel/v1`
**Authentication**: Bearer tokens (JWT) from Apple Sign In or email authentication
**Content-Type**: `application/json`
**Rate Limiting**: 60 requests/minute per user, 10 burst

## Authentication Endpoints

### POST /auth/apple
Exchange Apple Sign In credentials for application JWT token.

**Request:**
```json
{
  "identity_token": "string",
  "authorization_code": "string",
  "user_info": {
    "name": {
      "firstName": "string",
      "lastName": "string"
    },
    "email": "string"
  }
}
```

**Response (201 Created):**
```json
{
  "access_token": "string",
  "refresh_token": "string",
  "expires_in": 86400,
  "token_type": "Bearer",
  "user": {
    "user_id": "string",
    "email": "string",
    "display_name": "string",
    "created_at": "2024-01-15T10:00:00Z",
    "sync_version": 1
  }
}
```

### POST /auth/refresh
Refresh expired access token using refresh token.

**Request:**
```json
{
  "refresh_token": "string"
}
```

**Response (200 OK):**
```json
{
  "access_token": "string",
  "expires_in": 86400,
  "token_type": "Bearer"
}
```

### DELETE /auth/logout
Invalidate current session and tokens.

**Response (204 No Content)**

## User Management

### GET /users/me
Get current user profile and statistics.

**Response (200 OK):**
```json
{
  "user_id": "string",
  "display_name": "string",
  "email": "string",
  "profile_picture_url": "string",
  "statistics": {
    "countries_visited": 25,
    "countries_percentage": 12.8,
    "us_states_visited": 15,
    "us_states_percentage": 29.4,
    "canadian_provinces_visited": 3,
    "canadian_provinces_percentage": 23.1,
    "total_regions_visited": 43,
    "total_regions_percentage": 16.6,
    "continents_visited": ["NA", "EU", "AS"]
  },
  "privacy_settings": {
    "share_stats": false,
    "public_profile": false
  },
  "notification_settings": {
    "sync_alerts": true,
    "milestone_alerts": true
  },
  "sync_version": 15,
  "last_sync_at": "2024-01-20T15:30:00Z",
  "created_at": "2024-01-15T10:00:00Z",
  "updated_at": "2024-01-20T15:30:00Z"
}
```

### PATCH /users/me
Update user profile information.

**Request:**
```json
{
  "display_name": "New Name",
  "privacy_settings": {
    "share_stats": true
  },
  "notification_settings": {
    "milestone_alerts": false
  },
  "sync_version": 15
}
```

**Response (200 OK):** Updated user object
**Response (409 Conflict):** Sync conflict detected

### DELETE /users/me
Delete user account and all associated data (GDPR compliance).

**Response (204 No Content)**

## Visited Places Management

### GET /visited-places
Get all visited places for the current user with optional filtering.

**Query Parameters:**
- `region_type`: Filter by country/us_state/canadian_province
- `since`: ISO 8601 timestamp for incremental sync
- `limit`: Max results (default: 100, max: 1000)
- `offset`: Pagination offset

**Response (200 OK):**
```json
{
  "visited_places": [
    {
      "composite_key": "user123_country_US",
      "user_id": "user123",
      "region_type": "country",
      "region_code": "US",
      "region_name": "United States",
      "visited_date": "2023-07-04T00:00:00Z",
      "notes": "Amazing road trip across multiple states!",
      "marked_at": "2024-01-15T14:22:00Z",
      "marked_from_device": "iPhone 15 Pro",
      "sync_version": 3,
      "last_modified_at": "2024-01-18T16:45:00Z",
      "is_deleted": false
    }
  ],
  "pagination": {
    "total": 43,
    "limit": 100,
    "offset": 0,
    "has_more": false
  },
  "sync_metadata": {
    "server_timestamp": "2024-01-20T15:35:00Z",
    "sync_version": 15
  }
}
```

### POST /visited-places
Create a new visited place.

**Request:**
```json
{
  "region_type": "country",
  "region_code": "FR",
  "region_name": "France",
  "visited_date": "2024-01-10T00:00:00Z",
  "notes": "Paris was incredible!",
  "client_operation_id": "op_123456",
  "device_id": "device_abc"
}
```

**Response (201 Created):** Visited place object
**Response (409 Conflict):** Already exists or sync conflict

### PATCH /visited-places/{composite_key}
Update an existing visited place.

**Request:**
```json
{
  "visited_date": "2024-01-12T00:00:00Z",
  "notes": "Updated notes after revisiting!",
  "sync_version": 3,
  "client_operation_id": "op_789012",
  "device_id": "device_abc"
}
```

**Response (200 OK):** Updated visited place object
**Response (409 Conflict):** Sync conflict detected
**Response (404 Not Found):** Place not found

### DELETE /visited-places/{composite_key}
Remove a visited place (soft delete for sync).

**Request:**
```json
{
  "sync_version": 3,
  "client_operation_id": "op_345678"
}
```

**Response (204 No Content)**
**Response (409 Conflict):** Sync conflict detected

### POST /visited-places/batch
Batch operations for multiple visited places (optimized for sync).

**Request:**
```json
{
  "operations": [
    {
      "operation_type": "create",
      "client_operation_id": "op_111",
      "data": {
        "region_type": "country",
        "region_code": "DE",
        "region_name": "Germany",
        "visited_date": "2024-01-05T00:00:00Z"
      }
    },
    {
      "operation_type": "update",
      "composite_key": "user123_country_US",
      "sync_version": 3,
      "client_operation_id": "op_222",
      "data": {
        "notes": "Updated notes"
      }
    },
    {
      "operation_type": "delete",
      "composite_key": "user123_us_state_TX",
      "sync_version": 5,
      "client_operation_id": "op_333"
    }
  ],
  "batch_id": "batch_456789",
  "device_id": "device_abc"
}
```

**Response (200 OK):**
```json
{
  "batch_id": "batch_456789",
  "results": [
    {
      "client_operation_id": "op_111",
      "status": "success",
      "visited_place": { /* created object */ }
    },
    {
      "client_operation_id": "op_222",
      "status": "conflict",
      "conflict_details": {
        "current_sync_version": 4,
        "client_version": 3,
        "conflicted_fields": ["notes"]
      }
    },
    {
      "client_operation_id": "op_333",
      "status": "success"
    }
  ],
  "server_timestamp": "2024-01-20T15:40:00Z",
  "new_sync_version": 16
}
```

## Geographic Reference Data

### GET /geo/countries
Get all country reference data.

**Query Parameters:**
- `continent`: Filter by continent code (NA, EU, AS, etc.)
- `include_boundaries`: Include boundary geometry URLs (default: false)

**Response (200 OK):**
```json
{
  "countries": [
    {
      "region_code": "US",
      "name": "United States of America",
      "display_name": "United States",
      "iso_alpha_2": "US",
      "iso_alpha_3": "USA",
      "continent_code": "NA",
      "capital": "Washington, D.C.",
      "population": 331900000,
      "bbox": {
        "north": 71.5388,
        "south": 18.7763,
        "east": -66.885444,
        "west": 170.5957
      },
      "center": {
        "lat": 39.8283,
        "lon": -98.5795
      },
      "boundary_urls": {
        "detailed": "https://s3.amazonaws.com/skratch-geo/countries/US_detailed.geojson",
        "simplified": "https://s3.amazonaws.com/skratch-geo/countries/US_simple.geojson"
      }
    }
  ],
  "total": 195,
  "data_version": "2024.1",
  "last_updated": "2024-01-01T00:00:00Z"
}
```

### GET /geo/us-states
Get US states and territories reference data.

### GET /geo/canadian-provinces
Get Canadian provinces and territories reference data.

### GET /geo/search
Search geographic regions by name.

**Query Parameters:**
- `q`: Search query string
- `types`: Comma-separated region types to search
- `limit`: Max results (default: 10, max: 50)

**Response (200 OK):**
```json
{
  "results": [
    {
      "region_code": "CA",
      "region_type": "country",
      "name": "Canada",
      "display_name": "Canada",
      "center": {"lat": 56.130366, "lon": -106.346771},
      "relevance_score": 0.95
    }
  ],
  "query": "cana",
  "total_results": 3
}
```

## Sync Operations

### POST /sync
Comprehensive sync operation for offline-first architecture.

**Request:**
```json
{
  "device_id": "device_abc",
  "last_sync_version": 12,
  "client_timestamp": "2024-01-20T15:30:00Z",
  "pending_operations": [
    {
      "operation_id": "op_sync_001",
      "operation_type": "create",
      "entity_type": "visited_place",
      "entity_data": {
        "region_type": "country",
        "region_code": "JP",
        "region_name": "Japan",
        "visited_date": "2024-01-18T00:00:00Z"
      },
      "client_version": 1,
      "client_timestamp": "2024-01-18T10:15:00Z"
    }
  ]
}
```

**Response (200 OK):**
```json
{
  "sync_successful": true,
  "new_sync_version": 16,
  "server_timestamp": "2024-01-20T15:35:00Z",
  "processed_operations": [
    {
      "operation_id": "op_sync_001",
      "status": "success",
      "server_version": 16,
      "entity": { /* created visited place */ }
    }
  ],
  "server_changes": [
    {
      "operation_type": "update",
      "entity_type": "visited_place",
      "entity_id": "user123_country_US",
      "entity_data": { /* updated data from another device */ },
      "server_version": 14,
      "server_timestamp": "2024-01-19T12:30:00Z"
    }
  ],
  "conflicts": [],
  "user_statistics": {
    "countries_visited": 26,
    "total_regions_visited": 44
  }
}
```

### GET /sync/status
Get current sync status and pending operations count.

**Response (200 OK):**
```json
{
  "user_sync_version": 16,
  "last_sync_at": "2024-01-20T15:35:00Z",
  "pending_operations": 0,
  "unresolved_conflicts": 0,
  "sync_health": "healthy"
}
```

## Data Export

### POST /export/travel-map
Generate exportable travel map data.

**Request:**
```json
{
  "format": "geojson",
  "include_notes": true,
  "region_types": ["country", "us_state"]
}
```

**Response (202 Accepted):**
```json
{
  "export_id": "export_123456",
  "status": "processing",
  "estimated_completion": "2024-01-20T15:40:00Z"
}
```

### GET /export/{export_id}
Get export status and download URL.

**Response (200 OK):**
```json
{
  "export_id": "export_123456",
  "status": "completed",
  "download_url": "https://s3.amazonaws.com/skratch-exports/user123/export_123456.geojson",
  "expires_at": "2024-01-21T15:40:00Z",
  "file_size_bytes": 15420
}
```

## Error Responses

### Standard Error Format
```json
{
  "error": {
    "code": "SYNC_CONFLICT",
    "message": "Data has been modified by another device",
    "details": {
      "current_version": 5,
      "expected_version": 3,
      "conflicted_fields": ["notes", "visited_date"]
    },
    "request_id": "req_123456789"
  }
}
```

### HTTP Status Codes
- `200 OK`: Success
- `201 Created`: Resource created
- `204 No Content`: Success with no response body
- `400 Bad Request`: Invalid request data
- `401 Unauthorized`: Invalid or missing authentication
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `409 Conflict`: Sync conflict or constraint violation
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

## Rate Limiting

**Headers included in responses:**
- `X-RateLimit-Limit`: Requests allowed per window
- `X-RateLimit-Remaining`: Requests remaining in current window
- `X-RateLimit-Reset`: Unix timestamp when window resets

**Rate Limits:**
- Standard endpoints: 60 requests/minute
- Sync endpoint: 10 requests/minute
- Batch operations: 5 requests/minute
- Export operations: 3 requests/hour

## Caching Strategy

**Client-side caching headers:**
- Geographic reference data: `Cache-Control: max-age=86400` (24 hours)
- User statistics: `Cache-Control: max-age=300` (5 minutes)
- Visited places: `Cache-Control: no-cache` (always validate)

## API Versioning

**Current Version:** v1
**Deprecation Policy:** 12 months notice for breaking changes
**Backward Compatibility:** New optional fields added without version increment

This API design supports:
✅ Efficient offline-first synchronization
✅ Batch operations for performance
✅ Comprehensive conflict resolution
✅ Mobile-optimized data transfer
✅ Robust error handling
✅ Scalable rate limiting
✅ GDPR-compliant data export/deletion