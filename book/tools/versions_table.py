#!/usr/bin/env python3
"""Write the table of tool versions into the overview chapter, from book/examples/container_versions.tsv.

Usage: versions_table.py [--check]

container_versions.sh reads the versions out of the images. This script picks the version of each tool
in the image that its rules really use, so that the table can't be mistyped. With --check nothing is
written, and the exit code says whether the chapter is current, and whether each tool was found.

Only the Python standard library is used.
"""

import csv
import re
import sys
from pathlib import Path

BOOK = Path(__file__).resolve().parents[1]
VERSIONS = BOOK / "examples/container_versions.tsv"
CHAPTER = BOOK / "part2/00-overview.md"
START = "<!-- versions table: start -->"
END = "<!-- versions table: end -->"

# Tool, conda package, key in config/.docker.yml of the image its rules use, and where it's used
TOOLS = [
    ("FastQC", "fastqc", "helpers", "All FastQC reports"),
    ("fastp", "fastp", "preprocess", "`preprocess`"),
    ("Bowtie2", "bowtie2", "bowtie2", "`preprocess`, `quantify`"),
    ("Bowtie2", "bowtie2", "assemble", "`assemble`"),
    ("SAMtools", "samtools", "bowtie2", "`preprocess`, `quantify`"),
    ("SAMtools", "samtools", "assemble", "`assemble`, `contig_annotate`"),
    ("SAMtools", "samtools", "helpers", "The generic rules"),
    ("SAMtools", "samtools", "concoct", "`assemble__concoct__run`"),
    ("Kraken2", "kraken2", "preprocess", "`read_annotate`"),
    ("Krona", "krona", "krona", "`read_annotate`"),
    ("SingleM", "singlem", "preprocess", "`read_annotate`"),
    ("sylph", "sylph", "sylph", "`read_annotate`"),
    ("MetaPhlAn", "metaphlan", "preprocess", "`read_annotate`"),
    ("HUMAnN", "humann", "humann", "`read_annotate`"),
    ("phyloFlash", "phyloflash", "phyloflash", "`read_annotate`"),
    ("DIAMOND", "diamond", "mag_annotate", "`read_annotate`, `contig_annotate`"),
    ("Nonpareil", "nonpareil", "preprocess", "`read_annotate`"),
    ("MEGAHIT", "megahit", "assemble", "`assemble`"),
    ("SPAdes (metaSPAdes)", "spades", "assemble", "`assemble`"),
    ("CONCOCT", "concoct", "concoct", "`assemble`"),
    ("MaxBin2", "maxbin2", "assemble", "`assemble`"),
    ("MetaBAT2", "metabat2", "assemble", "`assemble`"),
    ("Prodigal", "prodigal", "assemble", "`assemble`, `contig_annotate`"),
    ("HMMER", "hmmer", "assemble", "`assemble`, `contig_annotate`"),
    ("dRep", "drep", "assemble", "`assemble`"),
    ("CheckM", "checkm-genome", "assemble", "Inside dRep"),
    ("CoverM", "coverm", "quantify", "`quantify`"),
    ("featureCounts (Subread)", "subread", "subread", "`contig_annotate`"),
    ("QUAST", "quast", "mag_annotate", "`mag_annotate`"),
    ("CheckM2", "checkm2", "checkm2", "`mag_annotate`"),
    ("GTDB-Tk", "gtdbtk", "gtdbtk", "`mag_annotate`"),
    ("PhyloPhlAn", "phylophlan", "mag_annotate", "`mag_annotate`"),
    ("DRAM", "dram", "dram", "`mag_annotate`"),
    ("CAMPER", "camper_dram", "camper", "`mag_annotate`, `contig_annotate`"),
    ("Bakta", "bakta", "mag_annotate", "`mag_annotate`"),
    ("eggNOG-mapper", "eggnog-mapper", "eggnog", "`mag_annotate__eggnog`"),
    ("eggNOG-mapper", "eggnog-mapper", "mag_annotate", "`contig_annotate`"),
    ("Proteinortho", "proteinortho", "mag_annotate", "`mag_annotate`"),
    ("Tiara", "tiara", "tiara", "`eukaryote`"),
    ("REMAG", "remag", "remag", "`eukaryote`"),
]


def render():
    rows = list(csv.DictReader(VERSIONS.open(), delimiter="\t"))
    versions = {(row["key"], row["tool"]): row["version"] for row in rows}
    images = {row["key"]: row["image"] for row in rows}
    lines = ["| Tool | Version | Image | Used in |", "|------|---------|-------|---------|"]
    missing = []
    for tool, package, key, used in TOOLS:
        version = versions.get((key, package))
        if version is None:
            missing.append(f"{tool} in {key}")
            version = "not found"
        lines.append(f"| {tool} | {version} | `{images.get(key, key)}` | {used} |")
    return "\n".join(lines), missing


def main():
    table, missing = render()
    text = CHAPTER.read_text()
    new = re.sub(re.escape(START) + r".*?" + re.escape(END), lambda _: f"{START}\n{table}\n{END}", text, flags=re.S)
    for item in missing:
        print(f"no version for {item}")
    if "--check" in sys.argv:
        if new != text:
            print("the table of versions in part2/00-overview.md is out of date: run book/tools/versions_table.py")
            return 1
        print("table of versions is current")
        return 1 if missing else 0
    CHAPTER.write_text(new)
    print(f"wrote {CHAPTER.relative_to(BOOK.parent)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
