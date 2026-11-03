#!/usr/bin/env python3
"""Give the contigs of one assembly their pipeline ids, one line per sequence.

Usage: contig_ids.py <assembly_id> <contigs.fasta> > renamed.fasta

Contigs are numbered in file order as <assembly_id>:bin_NA@contig_<8 digits>. The bin stays "NA"
until MAGScoT has placed the contig in a bin, see label_binned_contigs.py; split_bins.sh and CoverM
later read it from the id. fourcac_to_contig_ids.py repeats this numbering, so change both together.

Only the Python standard library is used.
"""

import sys


def renamed_records(lines, assembly_id):
    """Yield one 'header newline sequence newline' string per FASTA record"""
    number = 0
    sequence = []
    for line in lines:
        if line.startswith(">"):
            if number:
                yield f">{assembly_id}:bin_NA@contig_{number:08d}\n{''.join(sequence)}\n"
            number += 1
            sequence = []
        else:
            sequence.append(line.strip())
    if number:
        yield f">{assembly_id}:bin_NA@contig_{number:08d}\n{''.join(sequence)}\n"


def main():
    assembly_id, fasta = sys.argv[1], sys.argv[2]
    with open(fasta) as lines:
        sys.stdout.writelines(renamed_records(lines, assembly_id))


if __name__ == "__main__":
    main()
