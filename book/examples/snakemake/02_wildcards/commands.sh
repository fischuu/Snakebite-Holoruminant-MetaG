snakemake --cores 1 # fails

snakemake --cores 1 results/sampleB_R2.count.txt

snakemake results/sampleC_R1.count.txt results/sampleC_R2.count.txt --cores 1 --quiet

ls results

snakemake --cores 1 --quiet results/sampleC_R1.count.txt 2>&1 | tail -n 1

snakemake --cores 1 results/sampleZ_R1.count.txt # fails

snakemake --cores 1 results/sampleA.count.txt # fails
