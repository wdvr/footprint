#!/usr/bin/env python3

import os

# Change to the iOS directory
os.chdir("/Users/wouter/dev/footprint/ios")

# Find all Swift files
swift_files = []
for root, dirs, files in os.walk("Footprint"):
    for file in files:
        if file.endswith(".swift"):
            swift_files.append(os.path.join(root, file))

# Find all test Swift files
test_files = []
for root, dirs, files in os.walk("FootprintTests"):
    for file in files:
        if file.endswith(".swift"):
            test_files.append(os.path.join(root, file))

# Find all UI test Swift files
ui_test_files = []
for root, dirs, files in os.walk("FootprintUITests"):
    for file in files:
        if file.endswith(".swift"):
            ui_test_files.append(os.path.join(root, file))

print(f"Found {len(swift_files)} Swift files")
print(f"Found {len(test_files)} test files")
print(f"Found {len(ui_test_files)} UI test files")

# Generate a simple xcodegen project.yml
project_yml = """
name: Footprint
options:
  bundleIdPrefix: com.wouterdevriendt
targets:
  Footprint:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: Footprint
        excludes:
          - "**/*.md"
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.wouterdevriendt.footprint
      SWIFT_VERSION: 6.0
      DEVELOPMENT_TEAM: N324UX8D9M
      CODE_SIGN_STYLE: Automatic
    entitlements:
      path: Footprint/Footprint.entitlements
  
  FootprintTests:
    type: bundle.unit-test
    platform: iOS  
    sources:
      - path: FootprintTests
    dependencies:
      - target: Footprint
  
  FootprintUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: FootprintUITests  
    dependencies:
      - target: Footprint
"""

with open("project.yml", "w") as f:
    f.write(project_yml)

print("Created project.yml")
print("Install xcodegen with: brew install xcodegen")
print("Then run: xcodegen generate")
