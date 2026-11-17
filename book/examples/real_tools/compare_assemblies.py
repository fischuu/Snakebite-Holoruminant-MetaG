#!/usr/bin/env python3
"""Compare two gzipped assemblies by their sequences, ignoring names, order and strand.

Usage: compare_assemblies.py <first.fa.gz> <second.fa.gz>

Only the Python standard library is used.
"""
import gzip
import sys

COMPLEMENT = str.maketrans("ACGTN", "TGCAN")


def sequences(path):
    found = []
    current = []
    with gzip.open(path, "rt") as handle:
        for line in handle:
            if line.startswith(">"):
                if current:
                    found.append("".join(current))
                current = []
            else:
                current.append(line.strip())
    if current:
        found.append("".join(current))
    return found


def strand_free(sequence):
    return min(sequence, sequence[::-1].translate(COMPLEMENT))


def main():
    first = sequences(sys.argv[1])
    second = sequences(sys.argv[2])
    set_first = {strand_free(s) for s in first}
    set_second = {strand_free(s) for s in second}
    only_first = set_first - set_second
    only_second = set_second - set_first
    print(f"contigs: {len(first)} and {len(second)}")
    print(f"bases: {sum(map(len, first))} and {sum(map(len, second))}")
    print(f"same contigs in the same order: {first == second}")
    print(f"only in the first: {len(only_first)} contigs, {sum(map(len, only_first))} bases")
    print(f"only in the second: {len(only_second)} contigs, {sum(map(len, only_second))} bases")


if __name__ == "__main__":
    main()
