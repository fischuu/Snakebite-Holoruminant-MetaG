#!/usr/bin/env python3
"""Count how Tiara and 4CAC, or Tiara and REMAG, label the same contigs.

Usage: compare_labels.py <tiara.tsv> <4cac.tsv or remag.tsv>

Tiara sees only the contigs above its minimum length, so these are the contigs that are compared, as far
as the other tool has them too. The table of 4CAC has the label in the column class, and REMAG's in the
column prediction.
Only the Python standard library is used.
"""
import collections
import csv
import sys


def main():
    with open(sys.argv[1]) as handle:
        tiara = {row["sequence_id"]: row["class_fst_stage"] for row in csv.DictReader(handle, delimiter="\t")}
    with open(sys.argv[2]) as handle:
        other = {row["contig_id"]: row.get("class") or row["prediction"] for row in csv.DictReader(handle, delimiter="\t")}
    compared = [contig for contig in tiara if contig in other]
    counts = collections.Counter((tiara[contig], other[contig]) for contig in compared)
    columns = sorted({pair[1] for pair in counts})
    print("Tiara\t" + "\t".join(columns))
    for label in sorted({pair[0] for pair in counts}):
        print(label + "\t" + "\t".join(str(counts[(label, column)]) for column in columns))
    print(f"contigs compared: {len(compared)}")


if __name__ == "__main__":
    main()
