#!/usr/bin/env python3

import re
import os

# Files that need to be added to the project
missing_files = [
    "Footprint/Models/PhotoLocation.swift",
    "Footprint/Utilities/Localizable.swift",
    "Footprint/Services/GeoLocationMatcher.swift",
    "Footprint/Onboarding/OnboardingView.swift",
]

# Read the project file
project_file = "/Users/wouter/dev/footprint/ios/Footprint.xcodeproj/project.pbxproj"
with open(project_file, "r") as f:
    content = f.read()

# Find a sample file reference to understand the format
sample_match = re.search(
    r'(\w{24}) /\* ([^*]+\.swift) \*/ = \{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = ([^;]+); sourceTree = "<group>"; \};',
    content,
)

if sample_match:
    print(f"Found sample reference: {sample_match.group(2)}")

    # Find the sources build phase
    sources_pattern = r"(\w{24}) /\* Sources \*/ = \{[^}]+files = \(([^)]+)\);"
    sources_match = re.search(sources_pattern, content)

    if sources_match:
        sources_uuid = sources_match.group(1)
        current_files = sources_match.group(2).strip()
        print(f"Found sources build phase: {sources_uuid}")

        # Generate UUIDs for new files (simple approach)
        import hashlib

        new_content = content
        new_build_files = []

        for file_path in missing_files:
            file_name = os.path.basename(file_path)
            if file_name in content:
                print(f"File {file_name} already in project")
                continue

            if not os.path.exists(f"/Users/wouter/dev/footprint/ios/{file_path}"):
                print(f"File {file_path} does not exist, skipping")
                continue

            # Generate a simple UUID based on filename
            uuid_source = f"file_{file_name}_{file_path}".encode()
            file_uuid = hashlib.md5(uuid_source).hexdigest()[:24].upper()
            build_uuid = hashlib.md5((uuid_source + b"_build")).hexdigest()[:24].upper()

            # Add file reference
            file_ref = f'{file_uuid} /* {file_name} */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = {file_name}; sourceTree = "<group>"; }};'

            # Add build file
            build_file = f"{build_uuid} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {file_name} */; }};"

            # Find insertion points
            file_ref_section = re.search(
                r"(/\* Begin PBXFileReference section \*/.*?)/\* End PBXFileReference section \*/",
                new_content,
                re.DOTALL,
            )
            build_file_section = re.search(
                r"(/\* Begin PBXBuildFile section \*/.*?)/\* End PBXBuildFile section \*/",
                new_content,
                re.DOTALL,
            )

            if file_ref_section and build_file_section:
                # Insert file reference
                new_content = new_content.replace(
                    "/* End PBXFileReference section */",
                    f"\t\t{file_ref}\n/* End PBXFileReference section */",
                )

                # Insert build file
                new_content = new_content.replace(
                    "/* End PBXBuildFile section */",
                    f"\t\t{build_file}\n/* End PBXBuildFile section */",
                )

                new_build_files.append(
                    f"\t\t\t\t{build_uuid} /* {file_name} in Sources */,"
                )
                print(f"Prepared to add {file_name}")

        if new_build_files:
            # Add to sources build phase
            new_files_str = "\n".join(new_build_files)
            sources_pattern = (
                r"(\w{24} /\* Sources \*/ = \{[^}]+files = \()([^)]+)(\);)"
            )
            new_content = re.sub(
                sources_pattern, rf"\1\2\n{new_files_str}\n\t\t\t\3", new_content
            )

            # Write back
            with open(project_file, "w") as f:
                f.write(new_content)
            print("Project file updated!")
        else:
            print("No files to add")
    else:
        print("Could not find sources build phase")
else:
    print("Could not find sample file reference")
