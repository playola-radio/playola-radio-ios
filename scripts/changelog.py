#!/usr/bin/env python3
"""Collect changelog.d/ notes into CHANGELOG.md at release time.

Pull requests never edit CHANGELOG.md; each adds its own file under
changelog.d/ (format in changelog.d/README.md), so release notes can't
conflict. `check` validates every note and prints them. `roll` moves them
into a dated version section, leaves ## [Unreleased] empty apart from a
pointer comment, and deletes exactly the files it read.

Bullets still under ## [Unreleased] (from branches opened before
changelog.d/ existed) are collected first, with the same strict rules.
Parsing never skips a line: anything other than a blank line, a one-line
<!-- comment -->, the ### Changes heading, or a "- " bullet is an error
naming file:line, and nothing is changed.
"""
from __future__ import annotations

import argparse
import datetime
import os
import re
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

CHANGELOG = "CHANGELOG.md"
FRAGMENT_DIR = "changelog.d"
FRAGMENT_README = "README.md"
UNRELEASED_HEADING = "## [Unreleased]"
CHANGES_HEADING = "### Changes"
UNRELEASED_COMMENT = (
    "<!-- Don't add notes here. Each pull request adds a file to changelog.d/ "
    "(see changelog.d/README.md); scripts/release.sh collects them into a "
    "version section. -->"
)
NO_CHANGES = "No user-facing changes."
VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")


class ChangelogError(Exception):
    pass


@dataclass
class Collected:
    changelog_lines: list[str]
    unreleased_start: int
    unreleased_end: int
    notes: list[str] = field(default_factory=list)
    fragments: list[Path] = field(default_factory=list)


def parse_notes(lines: list[str], source: str, first_line_number: int = 1):
    """Returns (notes, errors) for lines that may only hold blank lines,
    one-line comments, the ### Changes heading, and bullets under it."""
    notes: list[str] = []
    errors: list[str] = []
    in_changes = False
    for offset, raw_line in enumerate(lines):
        where = f"{source}:{first_line_number + offset}"
        line = raw_line.rstrip()
        if not line or (line.startswith("<!--") and line.endswith("-->")):
            continue
        if line == CHANGES_HEADING:
            in_changes = True
        elif line.startswith("#"):
            errors.append(f"{where}: unknown heading '{line}' (only '{CHANGES_HEADING}' is allowed)")
        elif line.startswith("- ") and line[2:].strip():
            if in_changes:
                notes.append(line[2:].strip())
            else:
                errors.append(f"{where}: bullet before '{CHANGES_HEADING}'")
        else:
            errors.append(
                f"{where}: unexpected line {line!r} (each note is one '- ' line; "
                "no wrapped lines, nested bullets, or multi-line comments)"
            )
    return notes, errors


def collect(root: Path) -> Collected:
    changelog_path = root / CHANGELOG
    if not changelog_path.is_file():
        raise ChangelogError(f"{CHANGELOG}: not found")
    lines = changelog_path.read_text(encoding="utf-8").splitlines()

    if UNRELEASED_HEADING not in lines:
        raise ChangelogError(f"{CHANGELOG}: no '{UNRELEASED_HEADING}' heading")
    start = lines.index(UNRELEASED_HEADING)
    end = next(
        (index for index in range(start + 1, len(lines)) if lines[index].startswith("## ")),
        len(lines),
    )

    collected = Collected(lines, start, end)
    notes, errors = parse_notes(lines[start + 1 : end], CHANGELOG, start + 2)
    collected.notes.extend(notes)

    fragment_dir = root / FRAGMENT_DIR
    entries = sorted(fragment_dir.iterdir()) if fragment_dir.is_dir() else []
    for path in entries:
        relative = f"{FRAGMENT_DIR}/{path.name}"
        if path.name == FRAGMENT_README or path.name.startswith("."):
            continue
        if path.suffix != ".md" or not path.is_file():
            errors.append(f"{relative}: not a .md file (notes go in {FRAGMENT_DIR}/<name>.md)")
            continue
        fragment_notes, fragment_errors = parse_notes(
            path.read_text(encoding="utf-8").splitlines(), relative
        )
        if not fragment_notes and not fragment_errors:
            fragment_errors.append(
                f"{relative}:1: no notes (add '- ' bullets under '{CHANGES_HEADING}', "
                "or delete the file if this pull request is a pure chore)"
            )
        errors.extend(fragment_errors)
        collected.notes.extend(fragment_notes)
        collected.fragments.append(path)

    if errors:
        raise ChangelogError("\n".join(errors))
    return collected


def format_notes(notes: list[str]) -> str:
    return "\n".join(f"- {note}" for note in notes) if notes else NO_CHANGES


def roll(root: Path, version: str, date: str) -> list[str]:
    if not version:
        raise ChangelogError("version is required")
    if not VERSION_PATTERN.match(version):
        raise ChangelogError(f"version must look like 1.2.3 (got {version!r})")

    collected = collect(root)
    lines = collected.changelog_lines
    if any(line.startswith(f"## [{version}]") for line in lines):
        raise ChangelogError(f"{CHANGELOG} already has a section for {version}")

    body = [CHANGES_HEADING, "", format_notes(collected.notes)] if collected.notes else [NO_CHANGES]
    new_lines = (
        lines[: collected.unreleased_start + 1]
        + ["", UNRELEASED_COMMENT, "", f"## [{version}] - {date}", ""]
        + body
        + [""]
        + lines[collected.unreleased_end :]
    )
    _write_atomically(root / CHANGELOG, "\n".join(new_lines).rstrip("\n") + "\n")
    for path in collected.fragments:
        path.unlink()
    return collected.notes


def _write_atomically(path: Path, text: str) -> None:
    descriptor, temp_path = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(text)
        os.replace(temp_path, path)
    except BaseException:
        os.unlink(temp_path)
        raise


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=".", help="repo root holding CHANGELOG.md and changelog.d/")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("check", help="validate every note and print them")
    roll_parser = commands.add_parser("roll", help="move every note into a version section of CHANGELOG.md")
    roll_parser.add_argument("--version", default="", help="release version, e.g. 7.5.0")
    roll_parser.add_argument("--date", default=None, help="release date YYYY-MM-DD (default: today)")
    args = parser.parse_args(argv)

    root = Path(args.root)
    try:
        if args.command == "check":
            notes = collect(root).notes
        else:
            notes = roll(root, args.version, args.date or datetime.date.today().isoformat())
    except ChangelogError as error:
        print(f"Changelog error:\n{error}", file=sys.stderr)
        return 1
    print(format_notes(notes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
