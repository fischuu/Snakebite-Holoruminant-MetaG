snakemake -s Snakefile.reserved --dry-run results/summary/sampleA.tsv # fails

snakemake --cores 1 --dry-run results/summary/sampleA.tsv

snakemake --cores 2 results/summary/sampleA.tsv

cat results/summary/sampleA.tsv

snakemake results/summary/sampleB.tsv --dag | dot -Tpng > dag.png

snakemake results/summary/sampleB.tsv --rulegraph | dot -Tpng > rulegraph.png

snakemake results/summary/sampleB.tsv --dry-run --printshellcmds --quiet rules

snakemake --summary results/summary/sampleA.tsv | cut -f 1,3,5

cp dag.png rulegraph.png /examples/figures/
