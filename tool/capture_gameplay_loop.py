#!/usr/bin/env python3
"""Capture isolated, acknowledged native gameplay-loop evidence."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import struct
import subprocess
import time

LOCALES = {'en', 'es', 'pt-BR', 'fr'}
SCENES = {
    'career-normal', 'training-normal', 'selection-normal', 'recap-normal',
    'training-comparison', 'player-normal', 'player-overall', 'player-attributes',
    'life-normal', 'life-purchase-review', 'creator-normal', 'creator-role',
    'hall', 'challenge-score', 'challenge-saved-plan',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device-id', required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    root = args.output_root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    inputs = sorted(Path('lib').rglob('*.dart')) + sorted(Path('packages/elevenward_core/lib').rglob('*.dart')) + [Path('integration_test/gameplay_loop_capture_test.dart')]
    source_hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in inputs}
    ready = re.compile(r'GAMEPLAY_CAPTURE_READY\|([^|]+)\|([^|]+)\|(\S+)')
    layout = re.compile(r'GAMEPLAY_CAPTURE_LAYOUT\|([^|]+)\|([^|]+)\|([0-9.]+)\|([0-9.]+)\|([0-9.]+)\|(dark|light)')
    process = subprocess.Popen([
        'flutter', 'drive', '--no-pub', '--verbose', '--driver=test_driver/app_store_capture_driver.dart',
        '--target=integration_test/gameplay_loop_capture_test.dart', '-d', args.device_id,
    ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    captured = {}
    layouts = {}
    started = time.time()
    status = None
    error = None
    try:
        for line in process.stdout:
            print(line, end='', flush=True)
            if 'Could not build the application' in line or 'Application failed to start' in line:
                raise RuntimeError('Native build/launch failed; refusing stale binary')
            match = layout.search(line)
            if match:
                locale, scene, width, height, scale, brightness = match.groups()
                if locale not in LOCALES or scene not in SCENES:
                    raise RuntimeError(f'Unexpected layout: {locale}/{scene}')
                normal = scene.endswith('-normal')
                if float(scale) != (1 if normal else 2):
                    raise RuntimeError('Text scale does not match scene')
                if not normal and (float(width), float(height)) != (320, 568):
                    raise RuntimeError('Compact logical surface mismatch')
                layouts[(locale, scene)] = {
                    'logicalSurface': {'width': float(width), 'height': float(height)},
                    'textScale': float(scale), 'brightness': brightness,
                    'surfaceKind': 'native' if normal else 'compact',
                }
                continue
            match = ready.search(line)
            if not match:
                continue
            locale, scene, ack_path = match.groups()
            key = (locale, scene)
            if locale not in LOCALES or scene not in SCENES or key in captured:
                raise RuntimeError(f'Unexpected/duplicate capture: {locale}/{scene}')
            if key not in layouts:
                raise RuntimeError('Capture lacks observed layout metadata')
            ack = Path(ack_path).resolve()
            if args.device_id not in ack.parts or ack.name != f'elevenward-gameplay-{locale}-{scene}.ack':
                raise RuntimeError('Acknowledgement outside dedicated Simulator')
            output = root / locale / f'{scene}.png'
            output.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(['xcrun', 'simctl', 'io', args.device_id, 'screenshot', '--type=png', str(output)], check=True, timeout=45)
            pixels = output.read_bytes()
            if pixels[:8] != b'\x89PNG\r\n\x1a\n':
                raise RuntimeError('Screenshot is not PNG')
            width, height = struct.unpack('>II', pixels[16:24])
            captured[key] = {
                'locale': locale, 'scene': scene, 'path': str(output.relative_to(root)),
                'pixelWidth': width, 'pixelHeight': height,
                'sha256': hashlib.sha256(pixels).hexdigest(), **layouts[key],
            }
            ack.touch()
        status = process.wait()
        if status:
            raise RuntimeError(f'Native integration process exited {status}')
        missing = {(locale, scene) for locale in LOCALES for scene in SCENES} - captured.keys()
        if missing:
            raise RuntimeError(f'Missing acknowledged captures: {sorted(missing)}')
    except BaseException as exc:
        error = str(exc)
        raise
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=15)
        if status is None:
            status = process.returncode
        drift = [str(path) for path in inputs if hashlib.sha256(path.read_bytes()).hexdigest() != source_hashes[str(path)]]
        manifest = {
            'source': 'acknowledged native Simulator simctl screenshots',
            'target': 'integration_test/gameplay_loop_capture_test.dart',
            'deviceId': args.device_id, 'reducedMotion': True,
            'isolatedDatabase': True, 'productionNetwork': False,
            'fixtureHttpAllowlist': ['GET /v1/elevenward/challenges/current'],
            'realAuthInitialized': False, 'billingInitialized': False,
            'durationSeconds': round(time.time() - started, 2),
            'processExitCode': status, 'error': error,
            'sourceHashesAtLaunch': source_hashes, 'sourceDriftDuringRun': drift,
            'captures': [captured[key] for key in sorted(captured)],
        }
        (root / 'native-capture-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Captured {len(captured)} acknowledged native gameplay screenshots')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
