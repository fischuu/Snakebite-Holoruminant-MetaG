#!/usr/bin/env python3
"""Check that the target of each module makes its own report, and no other, in a dry run.

Usage: check_module_targets.py <pipeline folder> [snakemake]

This also finds a loop, as a module's target asks for its report, and the report for the module's
results. The project is a temporary one with the repository's configuration, and empty files in place
of reads and databases. It needs Snakemake, but no containers and no data.

Only the Python standard library is used.
"""
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

MODULES = ["reads", "reference", "preprocess", "read_annotate", "assemble", "quantify", "mag_annotate", "contig_annotate", "eukaryote"]
IN_ALL = sorted(set(MODULES) - {"eukaryote"})
ATTEMPTS = 80


def place(root, relative):
    """An empty file. When a file turns out to be a folder for another input, it becomes a folder."""
    path = root / relative
    for parent in reversed(path.parents):
        if parent.is_file():
            parent.unlink()
        if not parent.exists():
            parent.mkdir()
    if not path.exists():
        path.touch()


def jobs_of(root, pipeline, snakemake, target):
    """The job table of a dry run, after making what's missing"""
    command = [snakemake, "-s", str(pipeline / "workflow/Snakefile"), "--configfile", "config/config.yaml", "--config",
               f"pipeline_folder={pipeline}/", "--cores", "8", target, "-n", "--forceall", "--quiet", "rules"]
    for _ in range(ATTEMPTS):
        result = subprocess.run(command, cwd=root, capture_output=True, text=True)
        text = result.stdout + result.stderr
        if "MissingInputException" not in text:
            if result.returncode != 0:
                sys.exit(f"{target}: the dry run failed:\n{text[-1500:]}")
            return dict(re.findall(r"^(\S+)\s+(\d+)\s*$", text, flags=re.M))
        missing = [line.strip() for line in text.split("affected files:", 1)[-1].splitlines() if line.startswith("    ")]
        if not missing:
            sys.exit(f"{target}: can't tell what's missing:\n{text[-1500:]}")
        for relative in missing:
            place(root, relative)
    sys.exit(f"{target}: still missing files after {ATTEMPTS} attempts")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    pipeline = Path(sys.argv[1]).resolve()
    snakemake = sys.argv[2] if len(sys.argv) > 2 else "snakemake"
    failures = 0
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder).resolve() / "project"
        root.mkdir()
        shutil.copytree(pipeline / "config", root / "config")
        for target, wanted in [(module, [module]) for module in MODULES] + [("all", IN_ALL), ("report", IN_ALL)]:
            jobs = jobs_of(root, pipeline, snakemake, target)
            found = sorted(name.replace("report__", "") for name in jobs if name.startswith("report__"))
            same = found == sorted(wanted)
            print(("ok  " if same else "FAIL"), target, "makes the reports of", ", ".join(found) or "nothing", "" if same else f"(expected {', '.join(sorted(wanted))})")
            failures += not same
    if failures:
        sys.exit(f"{failures} targets are wrong")
    print("All targets make the right reports.")


if __name__ == "__main__":
    main()
