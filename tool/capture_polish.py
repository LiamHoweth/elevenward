#!/usr/bin/env python3
"""Capture acknowledged native polish QA in a dedicated Simulator.

Compact scenes use a centered 320 x 568 logical surface and 200% text. Normal
scenes use the native logical surface and 100% text. Both use reduced motion.
PNG files retain full native Simulator pixels. These are evidence captures.
"""

from pathlib import Path
import argparse
import hashlib
import json
import re
import struct
import subprocess


LOCALES = {'en', 'es', 'pt-BR', 'fr'}
SCENES = {
    'map-zoom', 'map-favorites', 'performance', 'training-preset',
    'fitness-guidance', 'transfer-comparison', 'stat-explanation',
    'journal-filter',
    'world-normal', 'training-normal', 'offers-normal', 'player-normal',
}
DIAGNOSTIC_SCENES = {'diagnostic-search-country'}
TRAINING_SCENES = {'training-normal', 'training-load-controls'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device-id', required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    capture_mode = parser.add_mutually_exclusive_group()
    capture_mode.add_argument(
        '--journal-only', action='store_true',
        help='Recheck the four localized journal scenes and preserve the full-pass manifest.',
    )
    capture_mode.add_argument(
        '--training-only', action='store_true',
        help='Recheck eight localized training scenes and preserve earlier manifests.',
    )
    args = parser.parse_args()
    output_root = args.output_root.resolve()
    selected_scenes = ({'journal-filter'} if args.journal_only
                       else TRAINING_SCENES if args.training_only else SCENES)
    diagnostic_scenes = (set() if args.journal_only or args.training_only
                         else DIAGNOSTIC_SCENES)
    allowed_scenes = selected_scenes | diagnostic_scenes
    manifest_path = output_root / (
        'native-journal-recheck-manifest.json' if args.journal_only
        else 'native-training-recheck-manifest.json' if args.training_only
        else 'native-capture-manifest.json'
    )
    manifest_path.unlink(missing_ok=True)
    marker = re.compile(r'POLISH_CAPTURE_READY\|([^|]+)\|([^|]+)\|(\S+)')
    layout_marker = re.compile(
        r'POLISH_CAPTURE_LAYOUT\|([^|]+)\|([^|]+)\|([0-9.]+)\|'
        r'([0-9.]+)\|([0-9.]+)\|(dark|light)'
    )
    command = [
        'flutter', 'drive', '--no-pub',
        '--driver=test_driver/app_store_capture_driver.dart',
        '--target=integration_test/polish_capture_test.dart',
        '-d', args.device_id,
    ]
    if args.journal_only:
        command.append('--dart-define=POLISH_CAPTURE_JOURNAL_ONLY=true')
    if args.training_only:
        command.append('--dart-define=POLISH_CAPTURE_TRAINING_ONLY=true')
    process = subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, bufsize=1,
    )
    captured = {}
    diagnostics = {}
    layouts = {}
    try:
        for line in process.stdout:
            print(line, end='', flush=True)
            if ('Could not build the application' in line or
                    'Application failed to start' in line):
                raise RuntimeError('Native polish build/launch failed; refusing a stale binary')
            layout_match = layout_marker.search(line)
            if layout_match is not None:
                locale, scene, width, height, scale, brightness = layout_match.groups()
                if locale not in LOCALES or scene not in allowed_scenes:
                    raise RuntimeError('Unexpected polish layout marker')
                normal = scene.endswith('-normal')
                if float(scale) != (1 if normal else 2):
                    raise RuntimeError('Observed text scale does not match the scene')
                if not normal and (float(width), float(height)) != (320, 568):
                    raise RuntimeError('Compact scene did not use the requested logical surface')
                layouts[(locale, scene)] = {
                    'logicalSurface': {'width': float(width), 'height': float(height)},
                    'textScale': float(scale), 'brightness': brightness,
                    'surfaceKind': 'native' if normal else 'compact',
                }
                continue
            match = marker.search(line)
            if match is None:
                continue
            locale, scene, ack_path = match.groups()
            if locale not in LOCALES or scene not in allowed_scenes:
                raise RuntimeError('Unexpected polish capture marker')
            if (locale, scene) in captured or (locale, scene) in diagnostics:
                raise RuntimeError(f'Duplicate polish scene: {locale}/{scene}')
            if (locale, scene) not in layouts:
                raise RuntimeError('Capture has no observed layout metadata')
            ack = Path(ack_path).resolve()
            if (args.device_id not in ack.parts or
                    ack.name != f'elevenward-polish-{locale}-{scene}.ack'):
                raise RuntimeError('Acknowledgement is outside the dedicated Simulator')
            output = (output_root / 'diagnostics' / locale / f'{scene}.png'
                      if scene in diagnostic_scenes
                      else output_root / locale / f'{scene}.png')
            output.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run([
                'xcrun', 'simctl', 'io', args.device_id, 'screenshot',
                '--type=png', str(output),
            ], check=True, timeout=45)
            pixels = output.read_bytes()
            if pixels[:8] != b'\x89PNG\r\n\x1a\n':
                raise RuntimeError('simctl did not produce a PNG')
            width, height = struct.unpack('>II', pixels[16:24])
            collection = diagnostics if scene in diagnostic_scenes else captured
            collection[(locale, scene)] = {
                'locale': locale, 'scene': scene,
                'path': str(output.relative_to(output_root)),
                'pixelWidth': width, 'pixelHeight': height,
                'sha256': hashlib.sha256(pixels).hexdigest(),
                **layouts[(locale, scene)],
            }
            ack.touch()
        status = process.wait()
        if status:
            return status
        expected = {(locale, scene) for locale in LOCALES for scene in selected_scenes}
        missing = expected - captured.keys()
        if missing:
            raise RuntimeError(f'Missing acknowledged scenes: {sorted(missing)}')
        manifest = {
            'source': 'acknowledged native Simulator simctl screenshots',
            'deviceId': args.device_id,
            'target': 'integration_test/polish_capture_test.dart',
            'captureScope': ('journal-only' if args.journal_only else
                             'training-only' if args.training_only else 'full'),
            'dartDefines': {
                'POLISH_CAPTURE_JOURNAL_ONLY': args.journal_only,
                'POLISH_CAPTURE_TRAINING_ONLY': args.training_only,
            },
            'reducedMotion': True,
            'isolatedDatabase': True,
            'productionNetwork': False,
            'captures': [captured[key] for key in sorted(captured)],
            'diagnostics': [diagnostics[key] for key in sorted(diagnostics)],
        }
        output_root.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(
            json.dumps(manifest, indent=2) + '\n',
        )
        print(f'Captured {len(captured)} acknowledged native polish screenshots')
        return 0
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=15)


if __name__ == '__main__':
    raise SystemExit(main())
