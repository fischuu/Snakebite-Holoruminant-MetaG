#!/usr/bin/env python3
"""Write the rule reference of the book from the rule files.

Usage: rule_reference.py [--check]

Reads every .smk file under workflow/rules/ and writes book/appendix/rule-reference.md with one
entry per rule: description, inputs, outputs, log, container and resource escalation. The file is
generated, so it cannot drift away from the pipeline. With --check nothing is written, and the
exit code says whether the file on disk is current.

Only the Python standard library is used, so this also runs without Snakemake.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RULES = ROOT / "workflow/rules"
OUTPUT = ROOT / "book/appendix/rule-reference.md"
ESCALATION = ROOT / "config/escalation.yaml"

MODULE_ORDER = [
    "reads", "reference", "preprocess", "read_annotate", "assemble", "quantify",
    "mag_annotate", "contig_annotate", "eukaryote", "report", "helpers", "devel",
]
SECTIONS = ("input", "output", "log", "benchmark", "params")
HEADER = """# Rule reference {#sec-rule-reference}

This appendix is generated from the rule files by `book/tools/rule_reference.py`. Do not edit it by
hand. Paths are shown as they are written in the rules, so they use the path constants of
`workflow/rules/folders.smk`, which @sec-path-constants explains.

Rules without their own entry in `config/escalation.yaml` use the default escalation
(`small, medium, large`).
"""


def read_escalation():
    table = {}
    for line in ESCALATION.read_text().splitlines():
        match = re.match(r"(\w+)\s*:\s*(.+)", line)
        if match:
            table[match.group(1)] = match.group(2).split("#")[0].strip()
    return table


def split_rules(text):
    """Yield (rule name, lines of its body) for every top-level rule of a .smk file"""
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        match = re.match(r"(\s*)(?:rule|checkpoint)\s+(\w+)\s*:", lines[i])
        if not match:
            i += 1
            continue
        # A rule inside an "if" is indented, and so is its body
        indent = len(match.group(1))
        j = i + 1
        while j < len(lines) and (not lines[j].strip() or lines[j][:indent + 1].strip() == ""):
            j += 1
        yield match.group(2), [line[indent:] for line in lines[i + 1:j]]
        i = j


def docstring(body):
    text = "\n".join(body).strip()
    match = re.match(r'"""(.*?)"""', text, flags=re.S)
    if not match:
        return ""
    return " ".join(match.group(1).split())


def strip_comment(line):
    """A line without its comment. A # inside a string stays."""
    quote = None
    for i, char in enumerate(line):
        if quote:
            if char == quote and line[i - 1] != "\\":
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "#":
            return line[:i]
    return line


def split_items(lines):
    """Split the lines of a directive at its top-level commas, whatever the line breaks are.

    snakefmt wraps long items over several lines, so a line isn't an item. The spaces that joining
    the lines leaves inside brackets are removed.
    """
    stripped = (strip_comment(line).strip() for line in lines)
    text = " ".join(line for line in stripped if line)
    items, current, depth, quote = [], "", 0, None
    for i, char in enumerate(text):
        if quote:
            current += char
            if char == quote and text[i - 1] != "\\":
                quote = None
        elif char in "\"'":
            quote = char
            current += char
        elif char == "," and depth == 0:
            items.append(current)
            current = ""
        elif char == " " and current.endswith(("(", "[", "{")):
            continue
        else:
            if char in "([{":
                depth += 1
            elif char in ")]}":
                depth -= 1
                current = re.sub(r",?\s*$", "", current)
            current += char
    items.append(current)
    return [item.strip() for item in items if item.strip()]


def section(body, name):
    """The entries of one directive (input:, output: ...), one per top-level item"""
    collected, on = [], False
    for line in body:
        header = re.match(r"    (\w+)\s*:(.*)", line)
        if header:
            on = header.group(1) == name
            if on and header.group(2).strip():
                collected.append(header.group(2))
            continue
        if on and line.strip():
            collected.append(line)
    return split_items(collected)


def container(body):
    for i, line in enumerate(body):
        if re.match(r"    container\s*:", line):
            match = re.search(r'docker\["([^"]+)"\]', line + " " + (body[i + 1] if i + 1 < len(body) else ""))
            if match:
                return match.group(1)
    return None


def has_shell(body):
    return any(re.match(r"    (shell|run|script)\s*:", line) for line in body)


def render():
    escalation = read_escalation()
    modules = sorted(
        (path for path in RULES.iterdir() if path.is_dir()),
        key=lambda p: MODULE_ORDER.index(p.name) if p.name in MODULE_ORDER else 99,
    )
    out = [HEADER]
    total = 0
    for module in modules:
        out.append(f"\n## Module `{module.name}`\n")
        for path in sorted(module.rglob("*.smk")):
            rules = list(split_rules(path.read_text()))
            if not rules:
                continue
            out.append(f"\n### `{path.relative_to(RULES)}`\n")
            for name, body in rules:
                total += 1
                escaped = f"`{name}`"
                out.append(f"\n**{escaped}**\n")
                description = docstring(body)
                if description:
                    out.append(f"\n{description}\n")
                if not has_shell(body):
                    out.append("\nTarget rule: it runs nothing itself and only asks for these files.\n")
                rows = []
                for directive in SECTIONS:
                    for entry in section(body, directive):
                        if entry.startswith('"""'):
                            continue
                        rows.append(f"- {directive}: `{entry}`")
                image = container(body)
                if image:
                    rows.append(f"- container: `{image}` (see `config/.docker.yml`)")
                if has_shell(body):
                    rows.append(f"- escalation: {escalation.get(name, 'default')}")
                if rows:
                    out.append("\n" + "\n".join(rows) + "\n")
    out.append(f"\n---\n\nThis reference lists {total} rules.\n")
    return "".join(out)


def main():
    text = render()
    if "--check" in sys.argv:
        if not OUTPUT.exists() or OUTPUT.read_text() != text:
            print("book/appendix/rule-reference.md is out of date: run book/tools/rule_reference.py")
            return 1
        print("rule reference is current")
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(text)
    print(f"wrote {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
