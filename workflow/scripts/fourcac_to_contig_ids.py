#!/usr/bin/env python3
"""Translate 4CAC's per-contig classes from metaSPAdes node names to pipeline contig ids.

assemble__metaspades__run renames the records of metaSPAdes' contigs.fasta, in file order, to
<assembly_id>:bin_NA@contig_<8-digit record number>. This repeats that numbering on the same
contigs.fasta, then joins 4CAC's final classes (4CAC_classification.fasta, which despite its
name is a header-less "node,class" CSV) and the XGBoost scores they started from.

Only the Python standard library is used, so it runs in the 4CAC container as is.
"""

import argparse
import sys


def read_contig_order(path, assembly_id):
    """metaSPAdes node name -> pipeline contig id, numbered like assemble__metaspades__run"""
    ids = {}
    with open(path) as handle:
        for line in handle:
            if line.startswith(">"):
                # the metaspades rule keeps only the first word of the header (cut -f 1 -d " ")
                node = line[1:].split()[0]
                ids[node] = f"{assembly_id}:bin_NA@contig_{len(ids) + 1:08d}"
    return ids


def read_scores(path):
    """metaSPAdes node name -> [viral, plasmid, prokaryote, eukaryote] XGBoost scores"""
    with open(path) as handle:
        header = handle.readline().rstrip("\n").split("\t")
        scores = {}
        for line in handle:
            fields = line.rstrip("\n").split("\t")
            scores[fields[0]] = fields[1:]
    return header[1:], scores


def read_classes(path):
    """metaSPAdes node name -> 4CAC class"""
    classes = {}
    with open(path) as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line:
                node, label = line.rsplit(",", 1)
                classes[node] = label
    return classes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contigs", required=True, help="metaSPAdes contigs.fasta 4CAC was run on")
    parser.add_argument("--scores", required=True, help="classify_xgb.py output")
    parser.add_argument("--classification", required=True, help="classify_4CAC.py output")
    parser.add_argument("--assembly-id", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    ids = read_contig_order(args.contigs, args.assembly_id)
    score_names, scores = read_scores(args.scores)
    classes = read_classes(args.classification)

    # Every contig must have exactly one class and one set of scores, otherwise the numbering
    # (and with it every pipeline id) can't be trusted.
    for name, table in (("scores", scores), ("classes", classes)):
        if set(table) != set(ids):
            missing = len(set(ids) - set(table))
            extra = len(set(table) - set(ids))
            sys.exit(
                f"4CAC {name} don't match contigs.fasta: {missing} contigs missing, "
                f"{extra} unknown names"
            )

    with open(args.output, "w") as out:
        out.write("\t".join(["contig_id", "node_id", "class"] + score_names) + "\n")
        for node, contig_id in ids.items():
            out.write("\t".join([contig_id, node, classes[node]] + scores[node]) + "\n")


if __name__ == "__main__":
    main()
