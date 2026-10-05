#!/usr/bin/env python3
"""Drive the real Flutter UI and save exact native Simulator screenshots."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys


READY = re.compile(
    r"APP_STORE_CAPTURE_READY\|(?P<locale>[^|]+)\|"
    r"(?P<device>[^|]+)\|(?P<source>[^\s]+)"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--device-id", required=True)
    parser.add_argument(
        "--device-class",
        choices=("iphone-65", "ipad-13"),
        required=True,
    )
    parser.add_argument("--output-root", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_root = args.output_root.expanduser().resolve()
    command = [
        "flutter",
        "drive",
        "--driver=test_driver/app_store_capture_driver.dart",
        "--target=integration_test/app_store_capture_test.dart",
        "-d",
        args.device_id,
        f"--dart-define=APP_STORE_DEVICE_CLASS={args.device_class}",
        "--dart-define-from-file=config/production.json",
    ]
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        env=os.environ.copy(),
    )
    assert process.stdout is not None
    captures = 0
    for line in process.stdout:
        print(line, end="", flush=True)
        match = READY.search(line)
        if match is None:
            continue
        if match.group("device") != args.device_class:
            process.terminate()
            raise RuntimeError("Capture marker does not match requested device class.")
        output = (
            output_root
            / match.group("locale")
            / args.device_class
            / f"{match.group('source')}.png"
        )
        output.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [
                "xcrun",
                "simctl",
                "io",
                args.device_id,
                "screenshot",
                "--type=png",
                str(output),
            ],
            check=True,
        )
        captures += 1
    return_code = process.wait()
    if return_code != 0:
        return return_code
    if captures != 32:
        raise RuntimeError(f"Expected 32 captures, received {captures}.")
    print(f"Captured {captures} native {args.device_class} screenshots in {output_root}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
