#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

from typhoon_backend import ensure_service, stop_service, transcribe_audio


def main() -> int:
    parser = argparse.ArgumentParser(description="Linux Voice Typing Typhoon client")
    parser.add_argument("audio_file", nargs="?", help="Audio file to transcribe")
    parser.add_argument("--output", help="Write the final text to this file")
    parser.add_argument(
        "--profile",
        choices=["smart", "raw", "th_to_eng"],
        help="Override dictation profile",
    )
    parser.add_argument(
        "--ensure-service",
        action="store_true",
        help="Start the Typhoon worker and exit",
    )
    parser.add_argument(
        "--stop-service",
        action="store_true",
        help="Stop the Typhoon worker and exit",
    )
    parser.add_argument(
        "--no-wait",
        action="store_true",
        help="Return immediately after spawning the worker",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print the raw JSON response",
    )
    args = parser.parse_args()

    try:
        if args.stop_service and not args.audio_file:
            stop_service()
            return 0

        if args.ensure_service and not args.audio_file:
            ensure_service(wait=not args.no_wait)
            return 0

        if not args.audio_file:
            parser.error("audio_file is required unless --ensure-service is used")

        result = transcribe_audio(args.audio_file, profile=args.profile)
        text = result.get("text", "")

        if args.output:
            output_path = Path(args.output)
            output_path.write_text(text, encoding="utf-8")

        if args.json:
            print(json.dumps(result, ensure_ascii=False))
        else:
            print(text)

        return 0
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
