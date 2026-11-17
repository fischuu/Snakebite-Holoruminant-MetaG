#!/usr/bin/env python3
"""Check that the table of 4CAC has the right contig for each name of metaSPAdes.

Usage: check_4cac_ids.py <4cac.tsv> <assembly.fa.gz>

fourcac_to_contig_ids.py gives the NODE_* names of metaSPAdes the pipeline's contig names, by repeating
the numbering of contig_ids.py. The length in a NODE_* name must then be the length of that contig.
Only the Python standard library is used.
"""
import csv
import gzip
import re
import sys


def main():
    lengths = {}
    name = None
    with gzip.open(sys.argv[2], "rt") as handle:
        for line in handle:
            if line.startswith(">"):
                name = line[1:].split()[0]
                lengths[name] = 0
            else:
                lengths[name] += len(line.strip())
    with open(sys.argv[1]) as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    missing = sum(row["contig_id"] not in lengths for row in rows)
    wrong = sum(
        row["contig_id"] in lengths and int(re.search(r"_length_(\d+)_", row["node_id"]).group(1)) != lengths[row["contig_id"]]
        for row in rows
    )
    print(f"contigs in the assembly: {len(lengths)}")
    print(f"lines in the table: {len(rows)}")
    print(f"not in the assembly: {missing}")
    print(f"with another length: {wrong}")
    return 1 if missing or wrong else 0


if __name__ == "__main__":
    sys.exit(main())
