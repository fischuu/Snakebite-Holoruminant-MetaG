snakemake --cores 1

ls -l results | cut -c1-11,25-

ls results/bins

rm results/final.txt

snakemake --cores 1 --forceall --dry-run --quiet rules
