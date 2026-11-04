python python_basics.py

python pandas_samples.py

snakemake --cores 1

for file in results/*.fastq.gz; do echo "$file: $(zcat "$file" | wc -l | awk '{print $1 / 4}') reads"; done
