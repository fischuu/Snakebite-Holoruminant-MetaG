snakemake --cores 4 --quiet rules

cat logs/sampleA.log

cut -f 1,2,3,10 benchmarks/sampleA.tsv

snakemake --cores 1 --forceall --dry-run --quiet rules

snakemake --cores 1 --forceall --quiet rules

snakemake results/sampleA.txt --cores 4 --forceall --dry-run --set-threads sort_reads=4 | grep -E 'threads|resources'
