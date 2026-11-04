#!/usr/bin/env bash
# Run FastQC, Kraken2 and Krona by hand on a small scale, with the options of the pipeline's rules. Part IV quotes this.
# FastQC is too slow under emulation for all the reads, and the databases of Kraken2 are too large for a laptop, so
# Kraken2 gets a toy database with a single genome.
# Usage: small_demos.sh <project> > book/examples/transcripts/real_tools_small_demos.txt
# Needs a project from prepare.sh, which has run preprocess__fastp. Limited to 2 CPUs.
cd "$1" || exit 1
image=fischuu/hrp_preprocess:0.8
krona_image=fischuu/hrp_krona:0.1
taxonomy=https://a3s.fi/Holoruminant-data/2025.04.04.krona.tar.gz

in_container() {  # <image> <command>: run it in the folder demos
    docker run --rm --platform linux/amd64 --cpus 2 --entrypoint bash -v "$PWD/demos":/w -w /w "$1" -c "$2"
}

show() {
    echo "\$ $*"
    bash -c "$*" 2>&1
    echo
}

rm -rf demos
mkdir -p demos/k2db/taxonomy

gzip -dc reads/ERR2019410_1.fastq.gz | head -n 400000 | gzip > demos/raw.fq.gz
gzip -dc results/preprocess/fastp/ERR2019410.lib1_1.fq.gz | head -n 400000 | gzip > demos/trimmed.fq.gz
gzip -dc reads/ERR2019410_2.fastq.gz | head -n 400000 | gzip > demos/raw_2.fq.gz
in_container "$image" "fastqc raw.fq.gz trimmed.fq.gz" > demos/fastqc.log 2>&1

echo "### FastQC, on 100000 reads"
show "unzip -p demos/raw_fastqc.zip raw_fastqc/summary.txt | cut -f 1,2"
show "unzip -p demos/trimmed_fastqc.zip trimmed_fastqc/summary.txt | cut -f 1,2"
show "unzip -p demos/raw_fastqc.zip raw_fastqc/fastqc_data.txt | sed -n '/^>>Basic Statistics/,/^>>END_MODULE/p' | cut -f 1,2"
show "unzip -p demos/raw_fastqc.zip raw_fastqc/fastqc_data.txt | sed -n '/^>>Overrepresented/,/^>>END_MODULE/p'"

# The toy database: the genome of PhiX, labelled with its taxon, and a taxonomy of three lines
gzip -dc resources/reference/phix.fa.gz | sed '1s/.*/>phix|kraken:taxid|10847/' > demos/phix.fa
printf '1\t|\t1\t|\tno rank\t|\n10239\t|\t1\t|\tsuperkingdom\t|\n10847\t|\t10239\t|\tspecies\t|\n' > demos/k2db/taxonomy/nodes.dmp
printf '1\t|\troot\t|\t\t|\tscientific name\t|\n10239\t|\tViruses\t|\t\t|\tscientific name\t|\n10847\t|\tEscherichia virus phiX174\t|\t\t|\tscientific name\t|\n' > demos/k2db/taxonomy/names.dmp
# After fastp, as in the rule, but here the first 100000 pairs are enough
gzip -dc results/preprocess/fastp/ERR2019410.lib1_2.fq.gz | head -n 400000 | gzip > demos/trimmed_2.fq.gz
cat > demos/run_kraken2.sh <<'EOF'
set -euo pipefail
kraken2-build --add-to-library phix.fa --db k2db --no-masking > /dev/null 2>&1
kraken2-build --build --db k2db --threads 2 > build.log 2>&1
kraken2 --db k2db --threads 2 --gzip-compressed --paired --report sample.report --memory-mapping \
    trimmed.fq.gz trimmed_2.fq.gz 2> sample.log | pigz --processes 2 > sample.out.gz
EOF
in_container "$image" "bash run_kraken2.sh"

echo "### Kraken2, on a toy database with only PhiX"
show "cat demos/sample.log"
show "cat demos/sample.report"
show "gzip -t demos/sample.out.gz && echo complete"
show "gzip -dc demos/sample.out.gz | wc -l"
show "gzip -dc demos/sample.out.gz | cut -f 1 | sort | uniq -c"
show "gzip -dc demos/sample.out.gz | grep -m 2 '^C'"
show "gzip -dc demos/sample.out.gz | head -n 1"

curl -sS --fail "$taxonomy" | tar -xzf - -C demos
in_container "$krona_image" "ktImportTaxonomy -t 5 -m 3 sample.report -o chart.html --tax /w/krona" > demos/krona.log 2>&1

echo "### Krona, from that report"
show "tail -n 3 demos/krona.log"
show "grep -oE '<node name=\"[^\"]+\"' demos/chart.html"
show "grep -A 6 'phiX174\">' demos/chart.html | grep -oE '<magnitude><val>[0-9]+' | head -n 1"
