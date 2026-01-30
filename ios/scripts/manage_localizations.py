#!/usr/bin/env python3
"""
Footprint Localization Management Script

This script helps manage translations for the Footprint iOS app.
It can create new language directories, validate translations, and generate reports.

Usage:
    python3 manage_localizations.py --create-language es
    python3 manage_localizations.py --validate
    python3 manage_localizations.py --report
"""

import re
import argparse
from pathlib import Path
from typing import Dict

# Base directory for the iOS project
BASE_DIR = Path(__file__).parent.parent
RESOURCES_DIR = BASE_DIR / "Footprint" / "Resources"

# Supported languages with their display names
LANGUAGES = {
    "en": "English",
    "es": "Spanish",
    "fr": "French",
    "de": "German",
    "ja": "Japanese",
    # Planned languages
    "zh-CN": "Chinese (Simplified)",
    "pt": "Portuguese",
    "ru": "Russian",
    "it": "Italian",
    "ko": "Korean",
    "nl": "Dutch",
    "pl": "Polish",
    "tr": "Turkish",
    "ar": "Arabic",
    "he": "Hebrew",
    "th": "Thai",
    "vi": "Vietnamese",
    "sv": "Swedish",
    "no": "Norwegian",
    "da": "Danish",
}


def parse_strings_file(file_path: Path) -> Dict[str, str]:
    """Parse a .strings file and return a dictionary of key-value pairs."""
    strings = {}

    if not file_path.exists():
        return strings

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Regular expression to match "key" = "value"; format
    pattern = r'"([^"]+)"\s*=\s*"([^"]*)";\s*'
    matches = re.findall(pattern, content, re.MULTILINE | re.DOTALL)

    for key, value in matches:
        strings[key] = value

    return strings


def generate_report() -> None:
    """Generate a comprehensive localization status report."""
    print("\n" + "=" * 60)
    print("FOOTPRINT LOCALIZATION STATUS REPORT")
    print("=" * 60)

    # Check which languages are implemented
    implemented = []
    missing = []

    for lang_code, lang_name in LANGUAGES.items():
        if lang_code == "en":
            continue

        lang_dir = RESOURCES_DIR / f"{lang_code}.lproj"
        strings_file = lang_dir / "Localizable.strings"

        if strings_file.exists():
            implemented.append((lang_code, lang_name))
        else:
            missing.append((lang_code, lang_name))

    print("\n📊 SUMMARY:")
    print(f"   • Implemented languages: {len(implemented)}")
    print(f"   • Missing languages: {len(missing)}")
    print(f"   • Total target languages: {len(LANGUAGES) - 1}")  # -1 for English base

    if implemented:
        print("\n✅ IMPLEMENTED LANGUAGES:")
        for lang_code, lang_name in implemented:
            print(f"   🟢 {lang_name} ({lang_code})")

    if missing:
        print("\n❌ MISSING LANGUAGES:")
        for lang_code, lang_name in missing:
            print(f"   • {lang_name} ({lang_code})")


def main():
    parser = argparse.ArgumentParser(description="Manage Footprint app localizations")
    parser.add_argument(
        "--report", action="store_true", help="Generate a comprehensive status report"
    )

    args = parser.parse_args()

    if args.report:
        generate_report()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
