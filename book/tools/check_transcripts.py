#!/usr/bin/env python3
"""Check that terminal output quoted in the book is real.

Usage: check_transcripts.py

Every line in a ```text block of the chapters must appear in a recorded transcript under
book/examples/transcripts/. "[...]" marks a shortening. Blocks that are not terminal output use a
plain ``` fence instead, so they are not checked.

Only the Python standard library is used.
"""

import re
import sys
from pathlib import Path

BOOK = Path(__file__).resolve().parents[1]


def normal(line):
    """Ignore what legitimately differs between runs: job numbers, run ids, dates and sizes of columns"""
    line = line.strip()
    line = re.sub(r"^\$\s+", "", line)
    line = re.sub(r"SLURM jobid \d+", "SLURM jobid N", line)
    line = re.sub(r"(\.snakemake/slurm_logs/\S*?/)\d+\.log", r"\1N.log", line)
    line = re.sub(r"SLURM run ID: \S+", "SLURM run ID: X", line)
    line = re.sub(r"/scratch/project_demo/examples/[\w]+/", "", line)
    line = re.sub(r"[A-Z][a-z]{2} +\d+ \d\d:\d\d", "DATE", line)
    line = re.sub(r"Rules \w+ and \w+ are ambiguous", "Rules X and Y are ambiguous", line)
    line = re.sub(r"passed in [\d.]+s", "passed in Ns", line)
    if re.fullmatch(r"[\d.:\s]+", line):
        line = "NUMBERS"
    line = re.sub(r"\s+", " ", line)
    return line


def known_lines():
    lines = set()
    for path in (BOOK / "examples/transcripts").glob("*.txt"):
        for line in path.read_text().splitlines():
            lines.add(normal(line))
    return lines


def main():
    known = known_lines()
    problems = 0
    checked = 0
    for chapter in sorted(BOOK.glob("part*/*.md")):
        in_block = False
        for number, line in enumerate(chapter.read_text().splitlines(), 1):
            if line.startswith("```"):
                in_block = line.strip() == "```text" if not in_block else False
                continue
            if not in_block or not line.strip() or line.strip() == "[...]":
                continue
            checked += 1
            if normal(line) not in known and not any(normal(line) in other for other in known if len(normal(line)) > 20):
                problems += 1
                print(f"{chapter.relative_to(BOOK)}:{number}: {line[:120]}")
    print(f"{checked} quoted lines checked, {problems} not found in the transcripts")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
