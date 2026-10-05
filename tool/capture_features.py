#!/usr/bin/env python3
"""Capture acknowledged native feature fixtures in an isolated Simulator."""

from pathlib import Path
import argparse
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device-id', required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    marker = re.compile(r'FEATURE_CAPTURE_READY\|([^|]+)\|([^|]+)\|(\S+)')
    names = {'hub-fresh', 'ambition', 'journal', 'hall', 'archive', 'mentor',
             'loan-review', 'friends', 'challenge', 'support'}
    process = subprocess.Popen([
        'flutter', 'drive', '--no-pub',
        '--driver=test_driver/app_store_capture_driver.dart',
        '--target=integration_test/features_capture_test.dart',
        '-d', args.device_id,
    ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    captured = set()
    try:
        for line in process.stdout:
            print(line, end='', flush=True)
            if 'Could not build the application' in line or 'Application failed to start' in line:
                raise RuntimeError('Native feature build or launch failed; refusing a stale binary')
            match = marker.search(line)
            if match is None:
                continue
            locale, name, ack_path = match.groups()
            if locale not in {'en', 'es', 'pt-BR', 'fr'} or name not in names:
                raise RuntimeError('Unexpected capture marker')
            ack = Path(ack_path).resolve()
            if args.device_id not in ack.parts or ack.name != f'elevenward-features-{locale}-{name}.ack':
                raise RuntimeError('Acknowledgement is outside the dedicated Simulator')
            output = args.output_root.resolve() / locale / f'{name}.png'
            output.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(['xcrun', 'simctl', 'io', args.device_id, 'screenshot',
                            '--type=png', str(output)], check=True, timeout=45)
            ack.touch()
            captured.add((locale, name))
        status = process.wait()
        if status:
            return status
        if len(captured) != 40:
            raise RuntimeError(f'Expected 40 screenshots, got {len(captured)}')
        print(f'Captured {len(captured)} acknowledged native feature screenshots')
        return 0
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=15)


if __name__ == '__main__':
    raise SystemExit(main())
