#!/usr/bin/env python3
"""Write the small FASTQ files of the examples. They are random, but the same on every run."""
import gzip
import random
from pathlib import Path

SAMPLES = {"sampleA": 40, "sampleB": 60, "sampleC": 25}
out = Path(__file__).resolve().parent / "data"
out.mkdir(exist_ok=True)
random.seed(42)


def record(name):
    length = random.randint(30, 100)
    sequence = "".join(random.choice("ACGT") for _ in range(length))
    return f"@{name}\n{sequence}\n+\n{'I' * length}\n"


for sample, reads in SAMPLES.items():
    for mate in (1, 2):
        text = "".join(record(f"{sample}.{i}/{mate}") for i in range(reads))
        with open(out / f"{sample}_R{mate}.fastq.gz", "wb") as handle:
            handle.write(gzip.compress(text.encode(), mtime=0))
