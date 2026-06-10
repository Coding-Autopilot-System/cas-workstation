#!/usr/bin/env python3
"""Validate JSON instances against local Draft 2020-12 schemas."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    from jsonschema import Draft202012Validator, FormatChecker
except ImportError as exc:
    print(f"jsonschema dependency is required: {exc}", file=sys.stderr)
    raise SystemExit(2) from exc


def load_json(path: Path) -> object:
    with path.open("r", encoding="utf-8-sig") as handle:
        return json.load(handle)


def validate(schema_path: Path, instance_path: Path) -> list[str]:
    schema = load_json(schema_path)
    instance = load_json(instance_path)
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    return [
        f"{instance_path}: {'/'.join(str(part) for part in error.path) or '<root>'}: {error.message}"
        for error in sorted(validator.iter_errors(instance), key=lambda item: list(item.path))
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--schema", required=True, type=Path)
    parser.add_argument("--instance", required=True, type=Path)
    parser.add_argument("--expect-invalid", action="store_true")
    args = parser.parse_args()

    for path in (args.schema, args.instance):
        if not path.is_file():
            print(f"Required JSON file does not exist: {path}", file=sys.stderr)
            return 2

    try:
        errors = validate(args.schema, args.instance)
    except (json.JSONDecodeError, ValueError) as exc:
        print(f"Validation input is invalid: {exc}", file=sys.stderr)
        return 2

    if args.expect_invalid:
        if errors:
            return 0
        print(f"Expected invalid instance passed validation: {args.instance}", file=sys.stderr)
        return 1

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

