#!/usr/bin/env python3
"""Check that the book covers the pipeline as it is now.

Usage: check_sync.py [--base BRANCH]

Fails when:
- the generated rule reference is out of date,
- a rule, tool or container of the pipeline is not named in the written chapters,
- a chapter names a rule that no longer exists,
- a chapter in _quarto.yml is missing, or a chapter file is not listed there,
- with --base: workflow/ or config/ changed against that branch, but book/ did not.

Only the Python standard library and git are used, so it can run anywhere, also in CI.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BOOK = ROOT / "book"
RULES = ROOT / "workflow/rules"
DOCKER = ROOT / "config/.docker.yml"
GENERATED = {BOOK / "appendix/rule-reference.md"}
# Rule names that only exist inside the examples or as illustrations in the text
NOT_PIPELINE_RULES = {"qc__filter", "qc__report", "qc__fragile__run", "qc__filter__run", "stats__count"}


def pipeline_rules():
    names = set()
    for path in RULES.rglob("*.smk"):
        names.update(re.findall(r"^\s*(?:rule|checkpoint)\s+(\w+)\s*:", path.read_text(), flags=re.M))
    return names


def docker_keys():
    return re.findall(r"^([\w-]+)\s*:", DOCKER.read_text(), flags=re.M)


def chapters_in_config():
    text = (BOOK / "_quarto.yml").read_text()
    return re.findall(r"^\s*-\s+([\w./-]+\.md)\s*$", text, flags=re.M)


def written_text():
    parts = []
    for path in BOOK.rglob("*.md"):
        if "examples" in path.parts or "_build" in path.parts or path in GENERATED or path.name == "README.md":
            continue
        parts.append(path.read_text())
    return "\n".join(parts)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", help="branch to compare with, to require book changes together with code changes")
    args = parser.parse_args()
    problems = []

    if subprocess.run([sys.executable, str(BOOK / "tools/rule_reference.py"), "--check"]).returncode:
        problems.append("the rule reference is out of date")

    listed = chapters_in_config()
    for chapter in listed:
        if not (BOOK / chapter).exists():
            problems.append(f"_quarto.yml lists {chapter}, which does not exist")
    for path in BOOK.rglob("*.md"):
        relative = path.relative_to(BOOK)
        if relative.parts[0] in ("part1", "part2", "part3", "part4", "appendix") and str(relative) not in listed:
            problems.append(f"{relative} is not listed in _quarto.yml")

    text = written_text()
    rules = pipeline_rules()
    missing = sorted(rule for rule in rules if not re.search(rf"\b{rule}\b", text))
    if missing:
        problems.append(f"{len(missing)} rules are not named in the written chapters: " + ", ".join(missing))

    mentioned = set(re.findall(r"\b((?:reads|reference|preprocess|read_annotate|assemble|quantify|mag_annotate|contig_annotate|eukaryote|report|helpers)__\w+)\b", text))
    stale = sorted(name for name in mentioned - rules - NOT_PIPELINE_RULES)
    if stale:
        problems.append("chapters name rules that do not exist: " + ", ".join(stale))

    images = sorted(key for key in docker_keys() if f'"{key}"' not in text and f"`{key}`" not in text and f"{key}:" not in text)
    if images:
        problems.append("containers not described: " + ", ".join(images))

    if args.base:
        changed = subprocess.run(["git", "diff", "--name-only", f"{args.base}...HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.split()
        code = [name for name in changed if name.startswith(("workflow/", "config/"))]
        book = [name for name in changed if name.startswith("book/")]
        if code and not book:
            problems.append(f"{len(code)} pipeline files changed against {args.base}, but nothing in book/")

    if problems:
        print("The book is out of sync with the pipeline:")
        for problem in problems:
            print(f"- {problem}")
        return 1
    print(f"The book covers all {len(rules)} rules and all containers.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
