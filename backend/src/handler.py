"""AWS Lambda handler using Mangum."""

from mangum import Mangum

from src.api.main import app

# Create the Lambda handler
# api_gateway_base_path strips the stage name from the path
handler = Mangum(app, lifespan="off", api_gateway_base_path="/dev")
