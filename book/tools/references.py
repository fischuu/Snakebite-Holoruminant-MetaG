#!/usr/bin/env python3
"""Write the list of all references, from the sections "Reference" of the tool chapters.

Usage: references.py [--check]

Writes book/appendix/references.md, sorted by author. With --check nothing is written, and the exit
code says whether the file on disk is current.

Only the Python standard library is used.
"""

import re
import sys
from pathlib import Path

BOOK = Path(__file__).resolve().parents[1]
OUTPUT = BOOK / "appendix/references.md"
HEADER = """# All references {#sec-references}

These are the references of the tool chapters in one list, for your methods section. This appendix is generated
by `book/tools/references.py`, so correct a reference in its chapter. @sec-tool-versions has the versions of the
tools. If you publish results from this pipeline, please cite the tools you used, with their versions.

"""
# Not the reference of a tool, but what all of it runs on
EXTRA = [
    "Mölder F, et al. (2021). Sustainable data analysis with Snakemake. *F1000Research*. "
    "<https://doi.org/10.12688/f1000research.29032.2>",
]


def references():
    found = set(EXTRA)
    for path in sorted((BOOK / "part2").glob("*.md")):
        for section in re.findall(r"(?ms)^## References?\n(.*?)(?=^#|\Z)", path.read_text()):
            for paragraph in section.split("\n\n"):
                paragraph = paragraph.strip()
                if not paragraph:
                    continue
                # Only the citation itself, without remarks after its link
                match = re.match(r"(.*?<https?://[^>]+>)", paragraph, flags=re.S)
                found.add(match.group(1) if match else paragraph)
    return sorted(found, key=str.casefold)


def render():
    return HEADER + "\n\n".join(references()) + "\n"


def main():
    text = render()
    if "--check" in sys.argv:
        if not OUTPUT.exists() or OUTPUT.read_text() != text:
            print("book/appendix/references.md is out of date: run book/tools/references.py")
            return 1
        print("references are current")
        return 0
    OUTPUT.write_text(text)
    print(f"wrote {OUTPUT.relative_to(BOOK.parent)}, {len(references())} references")
    return 0


if __name__ == "__main__":
    sys.exit(main())
