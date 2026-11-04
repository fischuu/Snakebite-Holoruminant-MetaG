#!/usr/bin/env bash
# Print what Part IV of the book quotes from a finished project, with each command before its output.
# Usage: show_results.sh <project> > book/examples/transcripts/real_tools.txt
# Everything runs in the project folder and without containers, so you can run the commands yourself.
cd "$1" || exit 1

show() {
    echo "\$ $*"
    bash -c "$*" 2>&1
    echo
}

echo "### The input"
show "cat config/samples.tsv | cut -f 1,2,3,7"
show "gzip -dc reads/ERR2019410_1.fastq.gz | head -n 4"

echo "### reads and reference"
show "ls results/reads | head -n 2"
show "ls results/reference/hosts"
show "gzip -dc results/reference/hosts/phix.fa.gz | head -n 2"

echo "### preprocess: fastp"
show "sed -n '/^Read1 before filtering/,/^\$/p' results/preprocess/fastp/ERR2019410.lib1.log"
show "sed -n '/^Read1 after filtering/,/^\$/p' results/preprocess/fastp/ERR2019410.lib1.log"
show "sed -n '/^Filtering result/,/^Insert size/p' results/preprocess/fastp/ERR2019410.lib1.log"
for library in ERR2019410 ERR2019412 ERR2019415; do
    show "grep -E '^reads passed filter|^reads failed due to low' results/preprocess/fastp/$library.lib1.log"
done

echo "### preprocess: host removal"
show "cat results/preprocess/bowtie2/phix/ERR2019410.lib1.log | grep -v bam_sort"
show "cat results/preprocess/bowtie2/phix/ERR2019410.lib1.flagstats.txt | head -n 8"
show "cat results/preprocess/quantification/phix/ERR2019410.lib1.chr_alignment_counts.tsv"
show "grep ^SN results/preprocess/bowtie2/phix/ERR2019410.lib1.stats.txt | cut -f 2,3 | head -n 9"

echo "### preprocess: the clean reads"
show "ls results/preprocess/bowtie2/decontaminated_reads | grep -v -E 'log|benchmark'"
show "gzip -t results/preprocess/bowtie2/decontaminated_reads/*.gz && echo all complete"
show "gzip -dc results/preprocess/bowtie2/decontaminated_reads/ERR2019410.lib1_1.fq.gz | wc -l"
show "gzip -dc results/preprocess/bowtie2/decontaminated_reads/ERR2019410.lib1_1.fq.gz | head -n 1"

echo "### read_annotate: Nonpareil"
show "cat results/read_annotate/nonpareil/nonpareil.tsv"

echo "### assemble: MEGAHIT"
show "grep -h 'k list' results/assemble/megahit/coasm.log | cut -d ' ' -f 4-"
show "grep -h 'contigs, total' results/assemble/megahit/ERR2019410.log | cut -d ' ' -f 4-"
show "grep -h 'contigs, total' results/assemble/megahit/coasm.log | cut -d ' ' -f 4-"
show "gzip -dc results/assemble/megahit/coasm.fa.gz | head -n 1"

echo "### assemble: mapping"
for library in ERR2019410 ERR2019412 ERR2019415; do
    show "grep 'overall alignment' results/assemble/bowtie2/coasm.$library.lib1.log"
done
show "grep -m 1 'Failed to build reference' results/assemble/bowtie2/coasm.ERR2019410.lib1.log"

echo "### assemble: binners"
show "tail -n 3 results/assemble/metabat2/ERR2019410.log"
show "tail -n 3 results/assemble/metabat2/coasm.log"
show "grep -E 'Bin files' results/assemble/maxbin2/coasm.log"
show "ls results/assemble/concoct/coasm | wc -l"
show "ls results/assemble/maxbin2/coasm results/assemble/metabat2/coasm"

echo "### assemble: MAGScoT"
show "wc -l results/assemble/magscot/coasm/prodigal.faa results/assemble/magscot/coasm/hmm.tblout results/assemble/magscot/coasm/contigs_to_bin.tsv | head -n 3"
show "head -n 3 results/assemble/magscot/coasm/hmm.tblout"
show "head -n 2 results/assemble/magscot/coasm/contigs_to_bin.tsv"
show "cut -f 1,2,3,4,7,8,10,13,14 results/assemble/magscot/coasm/magscot.scores.out"
show "cut -f 1,2,3,4,7,8,10,13,14 results/assemble/magscot/coasm/magscot.refined.out"
show "cut -f 1,2,3,4,7,8,10,13,14 results/assemble/magscot/ERR2019410/magscot.refined.out"
show "grep -E 'Refinement lead|no viable|continuing without' results/assemble/magscot/ERR2019410/magscot.log results/assemble/magscot/coasm/magscot.log"
show "gzip -dc results/assemble/magscot/coasm.fa.gz | head -n 1"

echo "### assemble: dRep"
show "ls results/assemble/drep/separated_bins results/assemble/drep/dereplicated_genomes | grep -v timestamp"
show "grep -E 'genomes were input|passed length|Running' results/assemble/drep/log/logger.log | cut -d ' ' -f 3- | cut -c 1-90 | head -n 8"
show "gzip -dc results/assemble/drep/dereplicated_genomes.fa.gz | grep -c '>'"
show "gzip -dc results/assemble/drep/dereplicated_genomes.fa.gz | grep -v '>' | tr -d '\\n' | wc -c"

echo "### quantify"
show "grep 'overall alignment' results/quantify/bowtie2/ERR2019410.lib1.log"
show "cat results/quantify/bowtie2/ERR2019410.lib1.flagstats.txt | head -n 8"
show "cat results/quantify/coverm/genome.count.tsv"
show "cat results/quantify/coverm/genome.covered_bases.tsv"
show "cat results/quantify/coverm/genome.length.tsv"
show "cat results/quantify/coverm/genome.tpm.tsv"
show "head -n 3 results/quantify/coverm/contig.count.tsv"
show "wc -l results/quantify/coverm/contig.count.tsv"

echo "### contig_annotate"
show "grep -c '>' results/contig_annotate/prodigal/coasm/coasm.prodigal.fa"
show "grep '>' results/contig_annotate/prodigal/coasm/coasm.prodigal.fa | head -n 2"
show "head -n 2 results/contig_annotate/prodigal/coasm/coasm.prodigal_plain.gtf"
show "sed -n 2,4p results/contig_annotate/featurecounts/coasm/coasm_ERR2019410.lib1.prodigal_fc.txt"
show "grep -v -E '\\s0\$' results/contig_annotate/featurecounts/coasm/coasm_ERR2019410.lib1.prodigal_fc.txt.summary"
for database in fe fefe nife; do
    show "grep -v -c '^#' results/contig_annotate/hmmer/$database/coasm.tblout.tsv"
done
show "grep -v '^#' results/contig_annotate/hmmer/nife/coasm.tblout.tsv | awk '{print \$1, \$3, \$5, \$6}'"
show "grep -v -c '^#' results/contig_annotate/hmmer/nife/coasm.domains-tblout.tsv"
show "cut -f 1,3 results/contig_annotate/camper/coasm/annotations.tsv | awk -F '\\t' 'NR > 1 && \$2 != \"\"' | wc -l"
show "wc -l results/contig_annotate/camper/coasm/annotations.tsv results/contig_annotate/camper/coasm/distillate.tsv | head -n 2"

echo "### mag_annotate: QUAST"
show "ls results/mag_annotate/quast | grep -v -E 'benchmark|quast.log|basic_stats|icarus'"
show "cut -f 1,2 results/mag_annotate/quast/report.tsv | head -n 20"

echo "### nCycDB"
show "cut -f 1-4 results/read_annotate/ncyc/ncyc_results.tsv | head -n 6"
show "wc -l results/read_annotate/ncyc/ncyc_results.tsv results/contig_annotate/ncyc/ncyc_results.tsv"
show "cut -f 1-3 results/contig_annotate/ncyc/ncyc_results.tsv | head -n 4"

echo "### eukaryote"
show "cat results/eukaryote/tiara/log_coasm.tsv | head -n 7"
show "cut -f 2 results/eukaryote/tiara/coasm.tsv | tail -n +2 | sort | uniq -c | sort -rn"
show "cut -f 1,2,3 results/eukaryote/tiara/coasm.tsv | head -n 3"
