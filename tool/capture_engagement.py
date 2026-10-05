#!/usr/bin/env python3
"""Capture native iOS engagement screens, acknowledging each completed image."""

from pathlib import Path
import argparse
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device-id', required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    marker = re.compile(r'ENGAGEMENT_CAPTURE_READY\|([^|]+)\|([^|]+)\|(\S+)')
    process = subprocess.Popen([
        'flutter', 'drive', '--no-pub',
        '--driver=test_driver/app_store_capture_driver.dart',
        '--target=integration_test/engagement_capture_test.dart',
        '-d', args.device_id, '--dart-define-from-file=config/production.json',
    ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    captured = set()
    try:
        for line in process.stdout:
            print(line, end='', flush=True)
            match = marker.search(line)
            if match is None:
                continue
            locale, name, ack_path = match.groups()
            if locale not in ('en', 'es', 'pt-BR', 'fr') or name not in (
                'resume', 'career', 'training', 'selection', 'recap', 'help',
                'settings', 'season',
            ):
                raise RuntimeError('Unexpected capture marker')
            ack = Path(ack_path).resolve()
            if args.device_id not in ack.parts or ack.name != f'elevenward-capture-{locale}-{name}.ack':
                raise RuntimeError('Acknowledgement is outside the dedicated simulator')
            output = args.output_root.resolve() / locale / f'{name}.png'
            output.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(['xcrun', 'simctl', 'io', args.device_id, 'screenshot',
                            '--type=png', str(output)], check=True, timeout=45)
            ack.touch()
            captured.add((locale, name))
        status = process.wait()
        if status:
            return status
        if len(captured) != 32:
            raise RuntimeError(f'Expected 32 screenshots, got {len(captured)}')
        print(f'Captured {len(captured)} acknowledged native screenshots')
        return 0
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=15)


if __name__ == '__main__':
    raise SystemExit(main())
