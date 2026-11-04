snakemake --cores 1 --quiet rules

zcat results/sampleA.fastq.gz | wc -l

snakemake --cores 1 --dry-run

snakemake --cores 1 --dry-run --quiet rules --config filter='{min_length: 80}'

snakemake --cores 1 --quiet rules --config filter='{min_length: 80}'

zcat results/sampleA.fastq.gz | wc -l
