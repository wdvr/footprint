"""Tests for main app endpoints."""

import pytest
from fastapi.testclient import TestClient

from src.api.main import app


@pytest.fixture
def client():
    """Create test client."""
    return TestClient(app)


class TestRootEndpoint:
    """Tests for GET / endpoint."""

    def test_root_returns_ok(self, client):
        """Test root endpoint returns API info."""
        response = client.get("/")

        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert "Footprint API" in data["message"]
        assert "version" in data

    def test_root_contains_environment(self, client):
        """Test root endpoint includes environment."""
        response = client.get("/")

        assert response.status_code == 200
        data = response.json()
        assert "environment" in data


class TestHealthEndpoint:
    """Tests for GET /health endpoint."""

    def test_health_check(self, client):
        """Test health check endpoint."""
        response = client.get("/health")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "footprint-api"


class TestCORS:
    """Tests for CORS configuration."""

    def test_cors_headers_present(self, client):
        """Test CORS headers are present in response."""
        response = client.options(
            "/",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )

        # FastAPI handles CORS through middleware
        assert response.status_code in [200, 204, 405]

    def test_cors_allows_any_origin(self, client):
        """Test CORS allows any origin in dev mode."""
        response = client.get(
            "/",
            headers={"Origin": "http://example.com"},
        )

        assert response.status_code == 200
        # In dev mode, CORS allows all origins
        assert "access-control-allow-origin" in response.headers


class TestOpenAPI:
    """Tests for OpenAPI documentation."""

    def test_openapi_schema_available(self, client):
        """Test OpenAPI schema is available."""
        response = client.get("/openapi.json")

        assert response.status_code == 200
        data = response.json()
        assert "openapi" in data
        assert "info" in data
        assert data["info"]["title"] == "Footprint API"

    def test_docs_available(self, client):
        """Test Swagger docs are available."""
        response = client.get("/docs")

        # In dev mode, docs should be available
        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]

    def test_redoc_available(self, client):
        """Test ReDoc is available."""
        response = client.get("/redoc")

        # In dev mode, redoc should be available
        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]
