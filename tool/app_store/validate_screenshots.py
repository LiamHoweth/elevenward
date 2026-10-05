#!/usr/bin/env python3
"""Validate the 64 App Store screenshots and write checksum manifests."""

from __future__ import annotations

import argparse
from io import BytesIO
import csv
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageCms

from compose_screenshots import DIMENSIONS, HEADLINES, STORIES


SOURCE_SCREENS = (
    "PlayerScreen — profile overview",
    "GameScreen — spotlight decision",
    "WorldScreen — club standing, next fixture, and results",
    "GameScreen — weekly focus and training workload",
    "PlayerScreen — active transfer request",
    "LifeScreen — relationships, agent, sponsors, wellness, and lifestyle",
    "LegacyScreen — honours and season archive",
    "CareerHubScreen — occupied slot and offline-ready state",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def profile_name(image: Image.Image) -> str:
    raw_profile = image.info.get("icc_profile")
    if raw_profile is None:
        raise ValueError("missing embedded ICC profile")
    profile = ImageCms.ImageCmsProfile(BytesIO(raw_profile))
    return ImageCms.getProfileName(profile).strip()


def main() -> int:
    args = parse_args()
    root = args.root.expanduser().resolve()
    manifest: list[dict[str, object]] = []
    errors: list[str] = []

    for locale in HEADLINES:
        for device, expected_size in DIMENSIONS.items():
            output_dir = root / locale / device
            expected_names = {story.output for story in STORIES}
            actual_names = {path.name for path in output_dir.glob("*.png")}
            if actual_names != expected_names:
                missing = sorted(expected_names - actual_names)
                extra = sorted(actual_names - expected_names)
                errors.append(
                    f"{locale}/{device}: missing={missing}, unexpected={extra}"
                )
            raw_dir = root / "raw" / locale / device
            for index, story in enumerate(STORIES, start=1):
                final_path = output_dir / story.output
                raw_path = raw_dir / story.source
                if not final_path.exists():
                    continue
                if not raw_path.exists():
                    errors.append(f"Missing raw capture {raw_path}")
                    continue
                for kind, path in (("final", final_path), ("raw", raw_path)):
                    try:
                        with Image.open(path) as image:
                            if image.format != "PNG":
                                errors.append(f"{path}: format is {image.format}, not PNG")
                            if image.size != expected_size:
                                errors.append(
                                    f"{path}: dimensions are {image.size}, expected {expected_size}"
                                )
                            if kind == "final" and image.mode != "RGB":
                                errors.append(
                                    f"{path}: mode is {image.mode}; expected RGB with no alpha"
                                )
                            if kind == "final":
                                name = profile_name(image)
                                if "srgb" not in name.lower():
                                    errors.append(f"{path}: ICC profile is {name!r}")
                    except (OSError, ValueError) as error:
                        errors.append(f"{path}: {error}")
                manifest.append(
                    {
                        "filename": story.output,
                        "path": str(final_path.relative_to(root)),
                        "locale": locale,
                        "device": device,
                        "width": expected_size[0],
                        "height": expected_size[1],
                        "sourceScreen": SOURCE_SCREENS[index - 1],
                        "sourceCapture": str(raw_path.relative_to(root)),
                        "headline": HEADLINES[locale][index - 1],
                        "sha256": sha256(final_path),
                    }
                )

    contact_sheets = sorted((root / "contact-sheets").glob("*.png"))
    if len(contact_sheets) != 8:
        errors.append(f"Expected 8 contact sheets, found {len(contact_sheets)}")
    if len(manifest) != 64:
        errors.append(f"Expected 64 manifest entries, found {len(manifest)}")

    manifest_path = root / "manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "fixture": {
                    "seed": 2,
                    "player": "Mika Vale",
                    "midCareer": {
                        "age": 26,
                        "overall": 82,
                        "club": "Northstar Athletic",
                        "division": "English Premier Division",
                        "nationalCaps": 3,
                        "earnedTrophies": 2,
                    },
                    "lateCareer": {"age": 34, "completedSeasons": 17},
                },
                "screenshots": manifest,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    csv_path = root / "manifest.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=manifest[0].keys())
        writer.writeheader()
        writer.writerows(manifest)

    report = {
        "passed": not errors,
        "screenshotCount": len(manifest),
        "contactSheetCount": len(contact_sheets),
        "checks": [
            "PNG format",
            "exact device dimensions",
            "final RGB pixels with no alpha channel",
            "final embedded sRGB ICC profile",
            "complete locale/device/story matrix",
            "raw capture provenance",
            "SHA-256 checksum manifest",
        ],
        "errors": errors,
    }
    (root / "validation-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Validated 64 screenshots and 8 contact sheets with no errors.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
