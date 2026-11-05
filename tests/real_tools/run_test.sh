#!/usr/bin/env bash
# Run the pipeline's rules with the real tools on 1 million read pairs per sample, and compare the results with
# the stored values in expected.tsv. Needs Docker and about 40 GB for the images. Takes a few hours under emulation.
# Usage: run_test.sh <folder with the *_subset.fastq.gz files> <new project folder>
# Set SNAKEMAKE and PYTHON if the first ones in the PATH aren't suitable, see book/examples/real_tools/README.md.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
tools="$repo/book/examples/real_tools"
project="$2"
bash "$tools/prepare.sh" "$1" "$project" 1000000
mkdir -p "$project"
project="$(cd "$project" && pwd)"
bash "$tools/run.sh" "$project" reference preprocess__fastp preprocess__bowtie2 preprocess__samtools \
    read_annotate__nonpareil assemble quantify contig_annotate__prodigal contig_annotate__featurecounts \
    contig_annotate__hmmer contig_annotate__camper eukaryote__tiara --keep-going > "$project/test_run.log" 2>&1 || true
"${PYTHON:-python3}" "$repo/tests/real_tools/check_results.py" "$project"
