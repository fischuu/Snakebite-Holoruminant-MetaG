#!/usr/bin/env bash
# Manually run kraken2 against the mock test database for every fastp-trimmed
# sample under results/preprocess/fastp/, staging the DB in /dev/shm first.
# Not called by any Snakemake rule -- a standalone debugging/testing helper.

set -euo pipefail

fastp_dir="results/preprocess/fastp/"
out_dir="kraken2"
db_src="resources/kraken2_mock"
db_shm="/dev/shm/$(basename "$db_src")"

mkdir --parents "$out_dir"
rsync --archive --recursive --verbose --times "$db_src" /dev/shm/
trap 'rm -rf "$db_shm"' EXIT

for r1 in "$fastp_dir"/*_1.fq.gz; do
    sample_id=$(basename "$r1" _1.fq.gz)
    echo "Processing sample ${sample_id} ..."

    kraken2 \
        --db "$db_shm" \
        --threads 24 \
        --paired \
        --gzip-compressed \
        --output >(pigz > "$out_dir/$sample_id.kraken2") \
        --report "$out_dir/$sample_id.kraken2.report" \
        "$fastp_dir/${sample_id}_1.fq.gz" \
        "$fastp_dir/${sample_id}_2.fq.gz" \
        > "$out_dir/${sample_id}.kraken2.log" 2>&1
done
