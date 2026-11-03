#!/usr/bin/env python3
"""Write MAGScoT's refined bins into the contig ids and keep only the contigs that are in a bin.

Usage: label_binned_contigs.py <refined.contig_to_bin.out> <table.tsv> <contigs.fasta> > binned.fasta

MAGScoT lists its refined bins in two columns: binnew (<output prefix>_cleanbin_<bin>) and contig
(<assembly>:bin_NA@contig_<number>, see contig_ids.py). A contig in bin 000001 becomes
<assembly>:bin_000001@contig_<number>. The table records this for every contig. A run without bins
leaves the refined file empty, and gives an empty table and an empty FASTA here.

Only the Python standard library is used.
"""

import csv
import sys

CLEANBIN_PREFIX = "magscot_cleanbin_"


def read_refined_bins(path):
    """One dict per binned contig, with the columns of the output table"""
    rows = []
    with open(path) as refined:
        for row in csv.DictReader(refined, delimiter="\t"):
            bin_id = row["binnew"].rsplit("/", 1)[-1].replace(CLEANBIN_PREFIX, "", 1)
            assembly_and_old_bin, contig_id = row["contig"].split("@", 1)
            assembly_id = assembly_and_old_bin.split(":", 1)[0]
            rows.append(
                {
                    "binnew": row["binnew"],
                    "contig": row["contig"],
                    "assembly_id": assembly_id,
                    "contig_id": contig_id,
                    "bin_id": bin_id,
                    "seqname": f"{assembly_id}:bin_{bin_id}@{contig_id}",
                }
            )
    return rows


def write_table(path, rows):
    with open(path, "w", newline="") as table:
        if rows:
            writer = csv.DictWriter(table, fieldnames=rows[0], delimiter="\t", lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)


def write_binned_contigs(path, new_ids, out):
    """Copy the records of the contigs in new_ids to out, under their new id"""
    keep = False
    with open(path) as fasta:
        for line in fasta:
            if line.startswith(">"):
                new_id = new_ids.get(line[1:].split()[0])
                keep = new_id is not None
                if keep:
                    out.write(f">{new_id}\n")
            elif keep:
                out.write(line)


def main():
    refined, table, contigs = sys.argv[1:4]
    rows = read_refined_bins(refined)
    write_table(table, rows)
    write_binned_contigs(contigs, {row["contig"]: row["seqname"] for row in rows}, sys.stdout)


if __name__ == "__main__":
    main()
