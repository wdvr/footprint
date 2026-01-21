#!/usr/bin/env python3
"""Script to build Lambda deployment package using Docker for Linux compatibility."""

import os
import shutil
import subprocess
import sys
from pathlib import Path

# Paths
ROOT_DIR = Path(__file__).parent.parent
BACKEND_DIR = ROOT_DIR / "backend"
INFRA_DIR = ROOT_DIR / "infrastructure"
BUILD_DIR = INFRA_DIR / "lambda_build"
PACKAGE_DIR = BUILD_DIR / "package"

# Runtime deps (not boto3 - it's in Lambda runtime)
REQUIREMENTS = [
    "fastapi",
    "mangum",
    "pydantic",
    "python-jose[cryptography]",
    "httpx",
    "python-dateutil",
]


def clean_build():
    """Clean previous build artifacts."""
    if BUILD_DIR.exists():
        shutil.rmtree(BUILD_DIR)
    BUILD_DIR.mkdir(parents=True)
    PACKAGE_DIR.mkdir(parents=True)


def install_dependencies_docker():
    """Install Python dependencies using Docker for Linux compatibility."""
    print("Installing dependencies with Docker...")

    req_file = BUILD_DIR / "requirements.txt"
    req_file.write_text("\n".join(REQUIREMENTS))

    # Use Amazon Linux 2 with Python for compatible binaries
    # Force x86_64 platform for Lambda compatibility
    docker_cmd = [
        "docker",
        "run",
        "--rm",
        "--platform",
        "linux/amd64",
        "-v",
        f"{BUILD_DIR}:/build",
        "-v",
        f"{PACKAGE_DIR}:/package",
        "--entrypoint",
        "",
        "public.ecr.aws/lambda/python:3.11",
        "/bin/bash",
        "-c",
        "pip install -r /build/requirements.txt -t /package --upgrade",
    ]

    subprocess.run(docker_cmd, check=True)


def install_dependencies_pip():
    """Install Python dependencies using pip with platform targeting."""
    print("Installing dependencies with pip...")

    req_file = BUILD_DIR / "requirements.txt"
    req_file.write_text("\n".join(REQUIREMENTS))

    # Install with Linux platform targeting
    subprocess.run(
        [
            sys.executable,
            "-m",
            "pip",
            "install",
            "-r",
            str(req_file),
            "-t",
            str(PACKAGE_DIR),
            "--platform",
            "manylinux2014_x86_64",
            "--implementation",
            "cp",
            "--python-version",
            "3.11",
            "--only-binary=:all:",
            "--upgrade",
            "--quiet",
        ],
        check=True,
    )


def copy_source():
    """Copy source code to package."""
    print("Copying source code...")

    src_dir = BACKEND_DIR / "src"
    dest_dir = PACKAGE_DIR / "src"

    if dest_dir.exists():
        shutil.rmtree(dest_dir)

    shutil.copytree(src_dir, dest_dir)

    # Create handler.py at root level that imports from src
    handler_content = '''"""AWS Lambda handler."""
from src.handler import handler

# Re-export handler for Lambda
__all__ = ["handler"]
'''
    (PACKAGE_DIR / "handler.py").write_text(handler_content)


def create_zip():
    """Create deployment zip file."""
    print("Creating deployment package...")

    zip_path = INFRA_DIR / "lambda_package"

    # Remove old zip if exists
    if Path(f"{zip_path}.zip").exists():
        os.remove(f"{zip_path}.zip")

    shutil.make_archive(str(zip_path), "zip", PACKAGE_DIR)

    zip_size = Path(f"{zip_path}.zip").stat().st_size / (1024 * 1024)
    print(f"Package created: {zip_path}.zip ({zip_size:.2f} MB)")

    return f"{zip_path}.zip"


def check_docker():
    """Check if Docker is available."""
    try:
        subprocess.run(["docker", "--version"], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def main():
    """Build Lambda deployment package."""
    print("Building Lambda deployment package...")

    clean_build()

    # Prefer Docker for reliable Linux builds, fall back to pip
    if check_docker():
        install_dependencies_docker()
    else:
        print("Docker not available, using pip with platform targeting...")
        install_dependencies_pip()

    copy_source()
    zip_path = create_zip()

    print(f"\nDeployment package ready: {zip_path}")
    print("Run 'pulumi up' to deploy.")


if __name__ == "__main__":
    main()
