#!/usr/bin/env python3
"""Reject stale workflow overrides before signing a release artifact."""

import re
import sys
from pathlib import Path


def validate(build_name: str, build_number: str) -> None:
    source = Path(__file__).resolve().parents[1] / "pubspec.yaml"
    match = re.search(r"^version: (\d+\.\d+\.\d+)\+(\d+)\s*$", source.read_text(), re.M)
    if match is None:
        raise ValueError("pubspec.yaml must declare a semantic version and build number.")
    version, minimum_build = match.groups()
    if build_name != version:
        raise ValueError(f"Release version must match pubspec.yaml ({version}).")
    if not re.fullmatch(r"[1-9]\d*", build_number) or int(build_number) < int(minimum_build):
        raise ValueError(f"Release build number must be an integer at least {minimum_build}.")


if __name__ == "__main__":
    try:
        if len(sys.argv) != 3:
            raise ValueError("Usage: validate_release_version.py BUILD_NAME BUILD_NUMBER")
        validate(*sys.argv[1:])
    except ValueError as error:
        sys.exit(str(error))
    print("Release version matches the source and the build number is current.")
