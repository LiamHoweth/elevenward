#!/usr/bin/env python3
"""Capture acknowledged real Flutter screens without touching player saves."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import signal
import struct
import subprocess
import sys
import time

READY = re.compile(r"APP_STORE_CAPTURE_READY\|([^|]+)\|([^|]+)\|([^|]+)\|(\S+)")
LOCALES = {"en", "es", "pt-BR", "fr"}
SCENES = {
    "01-player-profile", "02-spotlight-decision", "03-world-club",
    "04-weekly-focus", "05-transfer-request", "06-life-overview",
    "07-legacy", "08-career-hub",
}
IAP_SCENES = {
    "iap-all-access": "com.howethstudio.elevenward.all_access",
    "iap-vip": "com.howethstudio.elevenward.vip",
    "iap-double-development": "com.howethstudio.elevenward.double_development",
    "iap-double-money": "com.howethstudio.elevenward.double_money",
}


def stop_process(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=15)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=5)


def run_build(command: list[str]) -> None:
    process = subprocess.Popen(command, start_new_session=True)
    try:
        result = process.wait()
        if result:
            raise subprocess.CalledProcessError(result, command)
    finally:
        stop_process(process)


def player_data_hashes(device_id: str, bundle_id: str) -> dict[str, str]:
    result = subprocess.run([
        "xcrun", "simctl", "get_app_container", device_id, bundle_id, "data",
    ], capture_output=True, text=True, timeout=30)
    if result.returncode:
        return {}
    container = Path(result.stdout.strip()).resolve()
    if device_id not in container.parts:
        raise RuntimeError("Player-data inventory is outside the assigned Simulator.")
    protected = [container / "Documents", container / "Library/Application Support"]
    return {str(path.relative_to(container)): hashlib.sha256(path.read_bytes()).hexdigest()
            for directory in protected if directory.is_dir()
            for path in sorted(directory.rglob("*")) if path.is_file()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device-id", required=True)
    parser.add_argument("--device-class", choices=("iphone-65", "ipad-13", "iphone-compact"), required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--xcode-jobs", type=int, choices=(1, 2), default=2)
    parser.add_argument("--only-scene", choices=sorted(SCENES))
    args = parser.parse_args()
    def interrupted(signum, frame):
        raise KeyboardInterrupt(f"Capture interrupted by signal {signum}")
    signal.signal(signal.SIGTERM, interrupted)
    root = args.output_root.expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    source_paths = sorted(Path("lib").rglob("*.dart")) + sorted(Path("packages/elevenward_core/lib").rglob("*.dart"))
    source_paths += [Path("pubspec.yaml"), Path("pubspec.lock"), Path("integration_test/app_store_capture_test.dart"), Path("tool/app_store/career_fixture.dart"), Path(__file__), Path("test_driver/app_store_capture_driver.dart"), Path("ios/Runner.xcodeproj/project.pbxproj"), Path("ios/Runner/Info.plist")]
    source_hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in source_paths}
    source_version = re.search(r"^version: ([0-9.]+)\+(\d+)\s*$", Path("pubspec.yaml").read_text(), re.M)
    if source_version is None:
        raise RuntimeError("Missing source release version in pubspec.yaml.")
    definitions = [
        f"--dart-define=APP_STORE_DEVICE_CLASS={args.device_class}",
        "--dart-define-from-file=config/production.json",
        "--dart-define-from-file=config/marketing.json",
    ]
    if args.only_scene:
        definitions.append(f"--dart-define=APP_STORE_CAPTURE_ONLY_SCENE={args.only_scene}")
    derived = Path("build/app-store-simulator/DerivedData").resolve()
    binary = derived / "Build/Products/Debug-iphonesimulator/Runner.app"
    process = None
    captures = {}
    native_hashes = {}
    native_info = {}
    saved_data_before = {}
    error = None
    status = None
    status_bar_overridden = False
    started = time.time()
    try:
        # Configure Flutter once, then bound native compilation explicitly.
        # Driving a prebuilt bundle also avoids flutter drive's implicit clean.
        run_build([
            "flutter", "build", "ios", "--config-only", "--simulator", "--debug", "--no-pub",
            "--target=integration_test/app_store_capture_test.dart", *definitions,
        ])
        run_build([
            "xcodebuild", "-workspace", "ios/Runner.xcworkspace", "-scheme", "Runner",
            "-configuration", "Debug", "-sdk", "iphonesimulator", "-destination", f"id={args.device_id}",
            "-derivedDataPath", str(derived), "-jobs", str(args.xcode_jobs),
            "CODE_SIGNING_ALLOWED=NO", "ONLY_ACTIVE_ARCH=YES", "ARCHS=arm64",
            "COMPILER_INDEX_STORE_ENABLE=NO", "build",
        ])
        if not (binary / "Info.plist").is_file():
            raise RuntimeError("Fresh native capture bundle was not produced.")
        with (binary / "Info.plist").open("rb") as info_file:
            info = plistlib.load(info_file)
        native_info = {key: info.get(key) for key in (
            "CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion",
            "MinimumOSVersion", "CFBundleLocalizations",
        )}
        if (native_info["CFBundleShortVersionString"], str(native_info["CFBundleVersion"])) != source_version.groups():
            raise RuntimeError("Native capture bundle does not match the source release version/build.")
        for native_file in [binary / "Runner", binary / "Frameworks/App.framework/App"]:
            native_hashes[str(native_file.relative_to(binary))] = hashlib.sha256(native_file.read_bytes()).hexdigest()
        for native_file in [binary / "Runner.debug.dylib", binary / "Frameworks/App.framework/flutter_assets/kernel_blob.bin"]:
            if native_file.is_file():
                native_hashes[str(native_file.relative_to(binary))] = hashlib.sha256(native_file.read_bytes()).hexdigest()
        saved_data_before = player_data_hashes(args.device_id, native_info["CFBundleIdentifier"])
        subprocess.run([
            "xcrun", "simctl", "status_bar", args.device_id, "override", "--time", "9:41",
            "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3",
            "--cellularMode", "active", "--cellularBars", "4",
            "--batteryState", "charged", "--batteryLevel", "100",
        ], check=True, timeout=30)
        status_bar_overridden = True
        process = subprocess.Popen([
            "flutter", "drive", "--no-pub", "--driver=test_driver/app_store_capture_driver.dart",
            "--target=integration_test/app_store_capture_test.dart", "-d", args.device_id,
            f"--use-application-binary={binary}", *definitions,
        ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1,
            env=os.environ.copy(), start_new_session=True)
        assert process.stdout is not None
        for line in process.stdout:
            print(line, end="", flush=True)
            if "Could not build the application" in line or "Application failed to start" in line:
                raise RuntimeError("Native build/launch failed; refusing a stale binary.")
            marker = READY.search(line)
            if marker is None:
                continue
            locale, device, scene, ack_path = marker.groups()
            key = (locale, scene)
            if device != args.device_class or locale not in LOCALES or scene not in SCENES | IAP_SCENES.keys() or key in captures or (scene in IAP_SCENES and locale != "en"):
                raise RuntimeError(f"Unexpected or duplicate capture {locale}/{device}/{scene}")
            ack = Path(ack_path).resolve()
            if args.device_id not in ack.parts or ack.name != f"elevenward-store-{locale}-{scene}.ack":
                raise RuntimeError("Acknowledgment outside the assigned Simulator.")
            output = (root.parent / "iap-review" / locale / args.device_class / f"{IAP_SCENES[scene]}.png") if scene in IAP_SCENES else (root / locale / args.device_class / f"{scene}.png")
            output.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(["xcrun", "simctl", "io", args.device_id, "screenshot", "--type=png", str(output)], check=True, timeout=35)
            pixels = output.read_bytes()
            if pixels[:8] != b"\x89PNG\r\n\x1a\n":
                raise RuntimeError("simctl did not create a PNG.")
            width, height = struct.unpack(">II", pixels[16:24])
            captures[key] = {"locale": locale, "scene": scene, "path": os.path.relpath(output, root), "absolutePath": str(output), "pixelWidth": width, "pixelHeight": height, "sha256": hashlib.sha256(pixels).hexdigest()}
            if scene in IAP_SCENES:
                captures[key]["productId"] = IAP_SCENES[scene]
            ack.touch()
        status = process.wait()
        if status:
            raise RuntimeError(f"Native integration process exited {status}.")
        expected = ({(locale, args.only_scene) for locale in LOCALES} if args.only_scene else
                    ({(locale, scene) for locale in LOCALES for scene in SCENES} | {("en", scene) for scene in IAP_SCENES}))
        missing = expected - captures.keys()
        if missing:
            raise RuntimeError(f"Missing acknowledged captures: {sorted(missing)}")
    except BaseException as exc:
        error = str(exc)
        raise
    finally:
        if process is not None:
            stop_process(process)
            status = process.returncode if status is None else status
        if status_bar_overridden:
            subprocess.run(["xcrun", "simctl", "status_bar", args.device_id, "clear"], check=True, timeout=30)
        drift = [str(p) for p in source_paths if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest() != source_hashes[str(p)]]
        saved_data_after = player_data_hashes(args.device_id, native_info["CFBundleIdentifier"]) if native_info else {}
        changed_saved_data = [path for path, digest in saved_data_before.items() if saved_data_after.get(path) != digest]
        manifest = {
            "source": "acknowledged native Simulator simctl screenshots", "target": "integration_test/app_store_capture_test.dart",
            "deviceId": args.device_id, "requestedDeviceClass": args.device_class,
            "onlyScene": args.only_scene,
            "fixture": "deterministic career advanced by actual production engine", "isolatedTemporaryDatabase": True,
            "realAuthInitialized": False, "billingInitialized": False, "productionNetwork": False,
            "durationSeconds": round(time.time()-started, 2), "processExitCode": status, "error": error,
            "nativeBuildJobs": args.xcode_jobs, "nativeBuildDirectory": str(derived),
            "freshNativeBinary": str(binary),
            "nativeBinaryInfo": native_info, "nativeBinaryHashes": native_hashes,
            "existingProtectedPlayerDataHashes": saved_data_before,
            "changedProtectedPlayerDataPaths": changed_saved_data,
            "existingProtectedPlayerDataPreserved": not changed_saved_data,
            "sourceHashesAtLaunch": source_hashes, "sourceDriftDuringRun": drift,
            "captures": [captures[key] for key in sorted(captures)],
        }
        suffix = f"-{args.only_scene}" if args.only_scene else ""
        (root / f"native-capture-manifest-{args.device_class}{suffix}.json").write_text(json.dumps(manifest, indent=2)+"\n")
        review_manifest = dict(manifest)
        review_manifest["captures"] = [item for item in manifest["captures"] if "productId" in item]
        review_manifest["purchaseOrRestorePerformed"] = False
        review_manifest["paidOwnershipInjected"] = False
        review_root = root.parent / "iap-review"
        review_root.mkdir(parents=True, exist_ok=True)
        if not args.only_scene:
            (review_root / f"native-review-manifest-{args.device_class}.json").write_text(json.dumps(review_manifest, indent=2)+"\n")
    print(f"Captured {len(captures)} acknowledged native {args.device_class} screenshots in {root}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
