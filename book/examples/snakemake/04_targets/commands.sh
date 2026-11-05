snakemake --cores 2 --quiet rules

cat results/summary.tsv

snakemake counts --cores 1 --dry-run --forceall --quiet rules

snakemake --snakefile Snakefile.glob --cores 1 --dry-run --quiet rules

snakemake --list-rules

snakemake --list-target-rules
