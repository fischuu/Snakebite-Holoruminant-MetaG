snakemake --dry-run

snakemake --cores 1

cat results/sampleA_R1.count.txt

snakemake --cores 1

touch data/sampleA_R1.fastq.gz
snakemake --cores 1 --dry-run --quiet

cp data/sampleB_R1.fastq.gz data/sampleA_R1.fastq.gz
snakemake --cores 1 --dry-run | grep reason

snakemake --cores 1 --quiet

cat results/sampleA_R1.count.txt

snakemake --cores 1 --forceall --dry-run | grep reason
