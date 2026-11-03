#!/usr/bin/env python
"""Rewrite FASTA headers using a MAGScoT contig-to-bin mapping table.

Usage: reformat_fasta_magscot.py <input.fasta> <mapping.tsv>
The mapping table needs "contig" (old header) and "seqname" (new header)
columns; records whose header is not in the mapping are dropped.
"""
import sys

import pandas as pd
from Bio import SeqIO

input_fasta, input_mapping = sys.argv[1], sys.argv[2]

new_name = pd.read_table(input_mapping).set_index("contig")["seqname"].to_dict()

for record in SeqIO.parse(input_fasta, format="fasta"):
    if record.id in new_name:
        sys.stdout.write(f">{new_name[record.id]}\n{record.seq}\n")
