#!/usr/bin/env bash
# Print what Part IV of the book quotes from the runs of extra_tools.sh, with each command before its output.
# Usage: show_extra.sh <project> <project with metaSPAdes> <second project of the same run> > ../transcripts/real_tools_extra.txt
# Everything runs without containers, so you can run the commands yourself. The tables of FastQC need native_fastqc.sh first.
project=$1
spades=$2
repeat=$3
here="$(cd "$(dirname "$0")" && pwd)"
PYTHON="${PYTHON:-python3}"

show() {
    echo "\$ $*"
    bash -c "$*" 2>&1
    echo
}

# Shorter names in the transcript than the real folders of this computer
clean() {
    sed -e "s#\"$PYTHON\" #python3 #g" -e "s#\"$here/../../../#\"#g" -e "s#\"$here/#\"book/examples/real_tools/#g" -e "s#$project#first#g" -e "s#$repeat#second#g"
}

{
cd "$project" || exit 1

echo "### FastQC on all reads"
show "for f in results/reads/*_fastqc.zip results/preprocess/fastp/*_fastqc.zip results/preprocess/bowtie2/nonphix/*_fastqc.zip; do unzip -p \$f '*/summary.txt' | awk -F '\t' -v f=\$f '\$1 != \"PASS\" {print \$1, \$2, f}'; done | sed 's#results/##; s#_fastqc.zip##'"
show "unzip -p results/reads/ERR2019410.lib1_1_fastqc.zip '*/fastqc_data.txt' | sed -n '/^>>Basic Statistics/,/^>>END_MODULE/p' | cut -f 1,2"

echo "### Kraken2 and Krona with a real database"
show "cat results/read_annotate/kraken2/standard_08gb/ERR2019410.lib1.log"
show "head -n 12 results/read_annotate/kraken2/standard_08gb/ERR2019410.lib1.report"
show "grep -h 'sequences classified' results/read_annotate/kraken2/standard_08gb/*.log"
show "awk -F '\t' '\$4 == \"G\"' results/read_annotate/kraken2/standard_08gb/ERR2019410.lib1.report | sort -t \$'\t' -k 2,2nr | head -n 8"
show "grep -c '<node name=' results/read_annotate/krona/standard_08gb/ERR2019410.lib1.html"

echo "### DIAMOND with CAZy"
show "tail -n 3 results/read_annotate/diamond/cazy_ERR2019410_lib1.log"
show "head -n 3 results/read_annotate/diamond/cazy/ERR2019410.lib1_R1.out"
show "wc -l results/read_annotate/diamond/cazy/*.out"
show "head -n 3 results/read_annotate/diamond/cazy/summary_a.tsv | cut -f 1-3"
show "head -n 3 results/read_annotate/diamond/cazy/summary_b.tsv | cut -f 1-3"
show "tail -n +2 results/read_annotate/diamond/cazy/summary_a.tsv | awk -F '\t' '{s = 0; for (i = 2; i <= NF; i++) if (\$i != \"NA\") s += \$i; print s, \$1}' | sort -nr | head -n 5"
show "for f in a b; do awk -F '\t' -v f=\$f 'NR > 1 && \$2 != \"NA\" {s += \$2} END {print \"summary_\" f, s}' results/read_annotate/diamond/cazy/summary_\$f.tsv; done"
show "cut -f 1,2 results/read_annotate/diamond/benchmark/cazy_ERR2019410_lib1.tsv"

echo "### DIAMOND with HydDB"
show "tail -n 2 results/contig_annotate/diamond/hyddb_coasm.log"

echo "### sylph, with a database of the run's own genome"
show "cut -f 2,3,4,5,6,8,12 results/read_annotate/sylph/ERR2019410.lib1.profiling.tsv | sed 's#results/assemble/drep/dereplicated_genomes/##'"
show "cut -f 3,5,6,8,12 results/read_annotate/sylph/ERR2019412.lib1.profiling.tsv"
show "cut -f 3,5,6,8,12 results/read_annotate/sylph/ERR2019415.lib1.profiling.tsv"

echo "### phyloFlash"
show "tar -xzOf results/read_annotate/phyloflash/ERR2019410_lib1.phyloFlash.tar.gz ERR2019410_lib1.phyloFlash.report.csv | sed -n '8,12p;18,21p'"
show "tar -xzOf results/read_annotate/phyloflash/ERR2019410_lib1.phyloFlash.tar.gz ERR2019410_lib1.phyloFlash.NTUabundance.csv | head -n 8"
show "for l in ERR2019410 ERR2019412 ERR2019415; do tar -xzOf results/read_annotate/phyloflash/\${l}_lib1.phyloFlash.tar.gz \${l}_lib1.phyloFlash.NTUabundance.csv | grep -i '^Eukaryota' | head -n 3; echo; done"
show "grep -m 1 'Walltime' results/read_annotate/phyloflash/ERR2019410_lib1.phyloFlash.log"
show "for l in ERR2019410 ERR2019412 ERR2019415; do tar -xzOf results/read_annotate/phyloflash/\${l}_lib1.phyloFlash.tar.gz \${l}_lib1.phyloFlash.report.csv | grep '^NTU' | cut -d , -f 2 | xargs; done"
show "grep -A 1 'SPAdes exited' results/read_annotate/phyloflash/ERR2019410_lib1.phyloFlash.log"
show "tar -xzOf results/read_annotate/phyloflash/ERR2019410_lib1.phyloFlash.tar.gz ERR2019410_lib1.spades.out | grep -m 1 'qemu'"

echo "### CheckM2"
show "cut -f 1,2,3,4,6 results/mag_annotate/checkm2/quality_report.tsv"
show "cut -f 1,2 results/mag_annotate/checkm2/benchmark.tsv"

echo "### Bakta, with the light database"
show "cat results/mag_annotate/bakta/bakta.txt"
show "sed -n '6,8p' results/mag_annotate/bakta/bakta.tsv"
show "grep -c 'hypothetical protein' results/mag_annotate/bakta/bakta.tsv"
show "grep 'EXPERT-AMRFINDER' results/mag_annotate/bakta/bakta.log | cut -d ' ' -f 3-"
show "cut -f 1,2 results/mag_annotate/bakta/benchmark.tsv"

echo "### Proteinortho"
show "head -n 3 results/mag_annotate/proteinortho/proteinortho.proteinortho.tsv"
show "sed -n '/^# number of groups for each/,/^\$/p' results/mag_annotate/proteinortho/proteinortho.proteinortho-graph.summary"

echo "### REMAG, on the co-assembly of MEGAHIT"
show "grep -E 'Using device|Processed' results/eukaryote/remag/coasm.filter.log | perl -pe 's/\\e\\[[0-9;]*m//g' | cut -d '|' -f 3-"
show "cut -f 1,2 results/eukaryote/remag/benchmark/coasm.filter.tsv"
show "head -n 3 results/eukaryote/remag/coasm.tsv"
show "cut -f 3 results/eukaryote/remag/coasm.tsv | tail -n +2 | sort | uniq -c"
show "cat results/eukaryote/remag/coasm.bin.log"
show "\"$PYTHON\" \"$here/compare_labels.py\" results/eukaryote/tiara/coasm.tsv results/eukaryote/remag/coasm.tsv"

cd "$spades" || exit 1
echo "### metaSPAdes"
show "grep -m 1 'Memory limit' results/assemble/metaspades/coasm.log"
show "grep -m 1 'Thread limit\|Threads:' results/assemble/metaspades/coasm.log"
show "cut -f 1,2 results/assemble/metaspades/benchmark/coasm.tsv"
show "cut -f 1,2 results/assemble/metaspades/benchmark/ERR2019410.tsv"
show "ls -l results/assemble/metaspades | awk '{print \$5, \$9}' | grep -E 'coasm|ERR2019410.fa.gz|ERR2019410.tar.gz'"
show "gzip -dc results/assemble/metaspades/ERR2019410.fa.gz | awk '/^>/ {if (l) print l; l = 0; next} {l += length(\$0)} END {print l}' | sort -nr | awk '{n++; s += \$1; if (\$1 >= 200) a++; if (\$1 >= 500) b++; if (\$1 >= 1000) c++; if (\$1 >= 1500) d++; if (\$1 >= 1500) e += \$1} END {print \"contigs\", n, \"bases\", s; print \">= 200\", a; print \">= 500\", b; print \">= 1000\", c; print \">= 1500\", d, \"bases\", e}'"
show "gzip -dc results/assemble/metaspades/coasm.fa.gz | awk '/^>/ {if (l) print l; l = 0; next} {l += length(\$0)} END {print l}' | sort -nr | awk '{n++; s += \$1; if (\$1 >= 200) a++; if (\$1 >= 500) b++; if (\$1 >= 1000) c++; if (\$1 >= 1500) d++; if (\$1 >= 1500) e += \$1} END {print \"contigs\", n, \"bases\", s; print \">= 200\", a; print \">= 500\", b; print \">= 1000\", c; print \">= 1500\", d, \"bases\", e}'"

echo "### Tiara on metaSPAdes"
show "sed -n '1,7p' results/eukaryote/tiara/log_coasm.tsv"
show "sed -n '1,7p' results/eukaryote/tiara/log_ERR2019410.tsv"

echo "### 4CAC"
show "head -n 3 results/eukaryote/4cac/ERR2019410.tsv | cut -f 1,2,3,6,7"
show "cut -f 3 results/eukaryote/4cac/ERR2019410.tsv | tail -n +2 | sort | uniq -c | sort -nr"
show "grep -E 'contigs contained|corrected|propagation' results/eukaryote/4cac/ERR2019410.log"
show "cut -f 1,2 results/eukaryote/4cac/benchmark/ERR2019410.tsv"
show "grep -E 'Read [0-9]+ sequences|Killed' results/eukaryote/4cac/coasm.log.try1 | cut -c 1-60"
show "tail -n 1 results/eukaryote/4cac/coasm.log.try3"
show "\"$PYTHON\" \"$here/check_4cac_ids.py\" results/eukaryote/4cac/ERR2019410.tsv results/assemble/metaspades/ERR2019410.fa.gz"
show "\"$PYTHON\" \"$here/compare_labels.py\" results/eukaryote/tiara/ERR2019410.tsv results/eukaryote/4cac/ERR2019410.tsv"

echo "### Two runs of the same project"
show "cd \"$project\" && gzip -dc results/preprocess/bowtie2/decontaminated_reads/ERR2019410.lib1_1.fq.gz | md5"
show "cd \"$repeat\" && gzip -dc results/preprocess/bowtie2/decontaminated_reads/ERR2019410.lib1_1.fq.gz | md5"
show "\"$PYTHON\" \"$here/compare_assemblies.py\" \"$project/results/assemble/megahit/coasm.fa.gz\" \"$repeat/results/assemble/megahit/coasm.fa.gz\""
show "\"$PYTHON\" \"$here/compare_assemblies.py\" \"$project/results/assemble/megahit/ERR2019410.fa.gz\" \"$repeat/results/assemble/megahit/ERR2019410.fa.gz\""
show "ls \"$project/results/assemble/metabat2/coasm\" \"$repeat/results/assemble/metabat2/coasm\""
show "\"$PYTHON\" \"$here/../../../tests/real_tools/check_results.py\" \"$repeat\""
} | clean
