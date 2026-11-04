#!/usr/bin/env python3
"""Run the examples of the book and record what they print. Runs inside the mini cluster.

Usage: run_examples.py <examples folder> [example name ...]

Each folder under snakemake/ has a commands.sh. Its blocks, separated by blank lines, run one after
another in a fresh copy of the folder. The transcript shows each command after a "$" and its output,
and transcripts/<example>.txt keeps it. A block ending in "# fails" has to fail, every other block has
to succeed, so this also works as a test of the book's examples.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
wanted = sys.argv[2:]
scratch = Path("/scratch/project_demo/examples")
problems = 0


def clean(text):
    """Make transcripts stable: drop dates and job ids that differ on every run"""
    text = re.sub(r"\[[A-Z][a-z]{2} [A-Z][a-z]{2} +\d+ \d\d:\d\d:\d\d \d{4}\]", "[date]", text)
    text = re.sub(r"\.snakemake/log/\S+\.snakemake\.log", ".snakemake/log/<date>.snakemake.log", text)
    return text


for folder in sorted((root / "snakemake").iterdir()):
    if not (folder / "commands.sh").exists() or (wanted and folder.name not in wanted):
        continue
    work = scratch / folder.name
    if work.exists():
        shutil.rmtree(work)
    shutil.copytree(folder, work)
    shutil.copytree(root / "data", work / "data")
    lines = []
    failed = 0
    for block in re.split(r"\n\s*\n", (folder / "commands.sh").read_text().strip()):
        must_fail = block.rstrip().endswith("# fails")
        code = block.rstrip().removesuffix("# fails").rstrip()
        shown = "\n".join(line for line in code.splitlines() if not line.startswith("#!"))
        lines.append("\n".join(("$ " if i == 0 else "  ") + part for i, part in enumerate(shown.splitlines())))
        run = subprocess.run(["bash", "-c", code], cwd=work, capture_output=True, text=True)
        output = (run.stdout + run.stderr).rstrip()
        if output:
            lines.append(output)
        if must_fail and run.returncode:
            lines.append(f"[exit code {run.returncode}]")
        if (run.returncode != 0) != must_fail:
            failed += 1
            lines.append(f"!!! UNEXPECTED: exit code {run.returncode}")
        lines.append("")
    (root / "transcripts" / f"{folder.name}.txt").write_text(clean("\n".join(lines)) + "\n")
    print(f"{folder.name}: {'ok' if not failed else f'{failed} unexpected'}")
    problems += failed
sys.exit(1 if problems else 0)
