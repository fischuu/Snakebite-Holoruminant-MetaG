#!/bin/bash

# Usage: ./make_sample_tsv.sh /path/to/fastq_dir output.tsv

# Check arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_fastq_dir> <output_file>"
    exit 1
fi

FASTQ_DIR="$1"
OUTFILE="$2"

# Overwrite output if it exists
> "$OUTFILE"

# Loop over all fastq.gz files in the input directory
for fq in "$FASTQ_DIR"/*.fq.gz; do
    # Count reads (FASTQ has 4 lines per read)
    reads=$(zcat "$fq" | wc -l)
    reads=$((reads / 4))

    # Extract filename without extension
    sample=$(basename "$fq" .fq.gz)

    # Write to output file
    echo -e "$sample\t$reads" >> "$OUTFILE"
done

echo "Done. sample.tsv created at $OUTFILE"

