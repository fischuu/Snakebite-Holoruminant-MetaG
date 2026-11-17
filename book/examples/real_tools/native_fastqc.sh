#!/usr/bin/env bash
# FastQC on all files of a project, without emulation. Under emulation it took about 16 minutes per file, and these 18 files
# took much less on a native Java. It's the same program: the FastQC of the pipeline's image.
# Usage: native_fastqc.sh <project>
set -euo pipefail
project="$(cd "$1" && pwd)"
image=fischuu/hrp_preprocess:0.8
dist=$(mktemp -d)
trap 'rm -rf "$dist"' EXIT
docker run --rm --platform linux/amd64 --entrypoint bash -v "$dist":/out "$image" -c \
    'cp -r "$(dirname "$(readlink -f "$(which fastqc)")")"/. /out/'

run() {  # <output folder> <files>
    out=$1
    shift
    mkdir -p "$out"
    docker run --rm --cpus 2 -v "$project":"$project" -v "$dist":/fq -w "$project" eclipse-temurin:17-jre \
        java -Xmx2g -Djava.awt.headless=true -Dfastqc.output_dir="$out" -Dfastqc.threads=2 \
        -cp "/fq:/fq/sam-1.103.jar:/fq/jbzip2-0.9.jar:/fq/cisd-jhdf5.jar:/fq/htsjdk.jar" \
        uk.ac.babraham.FastQC.FastQCApplication "$@" > /dev/null 2>&1
}

cd "$project"
run results/reads results/reads/*_[12].fq.gz
run results/preprocess/fastp results/preprocess/fastp/*.lib1_[12].fq.gz
# The reads after the last host are the clean reads, under another name
for file in results/preprocess/bowtie2/decontaminated_reads/*_[12].fq.gz; do
    ln -sf "$project/$file" "results/preprocess/bowtie2/nonphix/$(basename "$file")"
done
run results/preprocess/bowtie2/nonphix results/preprocess/bowtie2/nonphix/*_[12].fq.gz
rm -f results/preprocess/bowtie2/nonphix/*_[12].fq.gz
