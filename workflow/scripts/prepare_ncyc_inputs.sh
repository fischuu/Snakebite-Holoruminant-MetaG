#!/bin/bash

# Usage:
# ./make_sample_tsv.sh <input_dir> <output_file> <file_type>
#
# Example:
# ./make_sample_tsv.sh data samples.tsv fq.gz
# ./make_sample_tsv.sh data samples.tsv fa

# Check arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input_dir> <output_file> <file_type>"
    echo "file_type examples: fq.gz, fastq.gz, fa, fasta"
    exit 1
fi

INPUT_DIR="$1"
OUTFILE="$2"
FILETYPE="$3"

# Overwrite output file
> "$OUTFILE"

# Decide read counting method
if [[ "$FILETYPE" == "fq.gz" || "$FILETYPE" == "fastq.gz" ]]; then
    MODE="FASTQ_GZ"
elif [[ "$FILETYPE" == "fq" || "$FILETYPE" == "fastq" ]]; then
    MODE="FASTQ"
elif [[ "$FILETYPE" == "fa" || "$FILETYPE" == "fasta" ]]; then
    MODE="FASTA"
else
    echo "Unsupported file type: $FILETYPE"
    exit 1
fi

# Loop over files
for file in "$INPUT_DIR"/*."$FILETYPE"; do
    [ -e "$file" ] || continue

    # Extract sample name
    sample=$(basename "$file" .$FILETYPE)

    # Count reads
    if [[ "$MODE" == "FASTQ_GZ" ]]; then
        reads=$(zcat "$file" | wc -l)
        reads=$((reads / 4))

    elif [[ "$MODE" == "FASTQ" ]]; then
        reads=$(wc -l < "$file")
        reads=$((reads / 4))

    elif [[ "$MODE" == "FASTA" ]]; then
        reads=$(grep -c "^>" "$file")
    fi

    echo -e "$sample\t$reads" >> "$OUTFILE"
done

echo "Done. Output written to $OUTFILE"
