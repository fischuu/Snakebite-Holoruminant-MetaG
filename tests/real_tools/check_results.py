#!/usr/bin/env python3
"""Compare the results of a run with the real tools against the stored values of an earlier run.

Usage: check_results.py <project folder> [--write]

Reads numbers from results/ and compares them with expected.tsv next to this script. With --write it
stores the numbers of this project as the new expected values. Do that only after you have looked at
the differences and decided that they are right, and say why in the commit.

Some tools give the same result every time, so their tolerance is 0. Others depend on random numbers
or on the order of their threads, and may differ a little, as does all that follows from them. A real
second run gave identical clean reads, but one contig more from MEGAHIT and one bin more from MetaBAT2.
A metric that a project doesn't have counts as
a failure, so that a rule that stopped producing a file can't go unnoticed.

Only the Python standard library is used.
"""

import csv
import gzip
import json
import re
import sys
from pathlib import Path

EXPECTED = Path(__file__).resolve().parent / "expected.tsv"
LIBRARIES = ("ERR2019410.lib1", "ERR2019412.lib1", "ERR2019415.lib1")
ASSEMBLIES = ("ERR2019410", "coasm")
EXACT = 0.0
SMALL = 0.05
RANDOM = 0.5


def fasta_stats(path):
    """Number of sequences and bases of a gzipped FASTA"""
    sequences = bases = 0
    try:
        with gzip.open(path, "rt") as handle:
            for line in handle:
                if line.startswith(">"):
                    sequences += 1
                else:
                    bases += len(line.strip())
    except (EOFError, OSError):
        return None, None
    return sequences, bases


def fastq_reads(path):
    """Number of reads of a gzipped FASTQ. A truncated file counts as missing, which is part of the test."""
    try:
        with gzip.open(path, "rt") as handle:
            return sum(1 for _ in handle) // 4
    except (EOFError, OSError):
        return None


def flagstat_mapped(path):
    match = re.search(r"^(\d+) \+ \d+ primary mapped", path.read_text(), flags=re.M)
    return int(match.group(1)) if match else None


def count_files(folder, pattern):
    return len(list(folder.glob(pattern))) if folder.is_dir() else None


def lines_without_header(path):
    return max(0, len(path.read_text().splitlines()) - 1)


def measure(project):
    """Yield (metric, value, tolerance as a share of the expected value). A value of None means that it is missing."""
    results = project / "results"

    for library in LIBRARIES:
        path = results / "preprocess/fastp" / f"{library}_fastp.json"
        report = json.loads(path.read_text()) if path.exists() else None
        for name, value in (
            ("reads_before", report and report["summary"]["before_filtering"]["total_reads"]),
            ("reads_after", report and report["summary"]["after_filtering"]["total_reads"]),
            ("low_quality", report and report["filtering_result"]["low_quality_reads"]),
            ("adapter_trimmed", report and report["adapter_cutting"]["adapter_trimmed_reads"]),
        ):
            yield f"fastp.{library}.{name}", value, EXACT

        path = results / "preprocess/bowtie2/phix" / f"{library}.flagstats.txt"
        yield f"host.{library}.mapped_reads", flagstat_mapped(path) if path.exists() else None, EXACT

        for end in (1, 2):
            path = results / "preprocess/bowtie2/decontaminated_reads" / f"{library}_{end}.fq.gz"
            yield f"clean.{library}.reads_{end}", fastq_reads(path) if path.exists() else None, EXACT

    for assembly in ASSEMBLIES:
        path = results / "assemble/megahit" / f"{assembly}.fa.gz"
        contigs, bases = fasta_stats(path) if path.exists() else (None, None)
        yield f"megahit.{assembly}.contigs", contigs, SMALL
        yield f"megahit.{assembly}.bases", bases, SMALL
        for binner, pattern in (("metabat2", "*.fa.gz"), ("maxbin2", "*.fa.gz"), ("concoct", "*.fa.gz")):
            yield f"{binner}.{assembly}.bins", count_files(results / "assemble" / binner / assembly, pattern), RANDOM
        path = results / "assemble/magscot" / assembly / "magscot.refined.out"
        yield f"magscot.{assembly}.refined_bins", lines_without_header(path) if path.exists() else None, RANDOM

    path = results / "assemble/drep/dereplicated_genomes"
    yield "drep.genomes", count_files(path, "*.fa.gz"), RANDOM

    for assembly in ASSEMBLIES:
        path = results / "contig_annotate/prodigal" / assembly / f"{assembly}.prodigal_plain.gtf"
        # These two follow the contigs, and MEGAHIT doesn't give exactly the same contigs twice
        yield f"prodigal.{assembly}.genes", lines_without_header(path) + 1 if path.exists() else None, SMALL
        path = results / "eukaryote/tiara" / f"{assembly}.tsv"
        yield f"tiara.{assembly}.classified_contigs", lines_without_header(path) if path.exists() else None, SMALL

    path = results / "read_annotate/nonpareil/nonpareil.tsv"
    if path.exists():
        with path.open() as handle:
            rows = {row["sample_id"]: row for row in csv.DictReader(handle, delimiter="\t")}
    else:
        rows = {}
    for library in LIBRARIES:
        coverage = rows.get(library, {}).get("C")
        yield f"nonpareil.{library}.has_coverage", (1 if coverage not in (None, "", "NA") else 0) if rows else None, EXACT


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    project = Path(sys.argv[1])
    measured = list(measure(project))

    if "--write" in sys.argv:
        with EXPECTED.open("w") as handle:
            handle.write("metric\tvalue\ttolerance\n")
            for metric, value, tolerance in measured:
                handle.write(f"{metric}\t{'' if value is None else value}\t{tolerance}\n")
        print(f"wrote {len(measured)} values to {EXPECTED}")
        return 0

    with EXPECTED.open() as handle:
        expected = {row["metric"]: row for row in csv.DictReader(handle, delimiter="\t")}
    failures = 0
    for metric, value, _ in measured:
        row = expected.get(metric)
        if row is None or row["value"] == "":
            continue
        want, tolerance = float(row["value"]), float(row["tolerance"])
        allowed = abs(want) * tolerance
        if tolerance >= RANDOM:
            # 1 bin against 2 is one contig more or less, which a share of a small number can't allow for
            allowed = max(allowed, 1)
        if value is None:
            print(f"FAILED: {metric}: expected {row['value']}, but the project doesn't have it")
            failures += 1
        elif abs(value - want) > allowed:
            print(f"FAILED: {metric}: expected {row['value']} (+/- {allowed:g}), got {value}")
            failures += 1
    if failures:
        print(f"{failures} of {len(expected)} values differ")
        return 1
    print(f"All {len(expected)} values as expected")
    return 0


if __name__ == "__main__":
    sys.exit(main())
