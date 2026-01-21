"""AWS Lambda handler using Mangum."""

from mangum import Mangum

from src.api.main import app

# Create the Lambda handler
handler = Mangum(app, lifespan="off")
