snakemake -s Snakefile.typo --cores 1 # fails

snakemake -s Snakefile.braces --cores 1 # fails

snakemake -s Snakefile.nooutput --cores 1 --latency-wait 1 # fails

snakemake -s Snakefile.fails --cores 1 # fails

cat logs/count.log

ls results || true

snakemake -s Snakefile.pipe --cores 1 --quiet

snakemake -s Snakefile.ambiguous --cores 1 # fails

snakemake -s Snakefile.good --cores 1 --quiet

sed -i 's/label="reads"/label="sequences"/' Snakefile.good
snakemake -s Snakefile.good --cores 1 --dry-run

snakemake -s Snakefile.good --cores 1 --dry-run --quiet --rerun-triggers mtime

snakemake -s Snakefile.good --cores 1 --touch --quiet

snakemake -s Snakefile.good --cores 1 --dry-run --quiet

snakemake -s Snakefile.slow --cores 1 > /dev/null 2>&1 &
sleep 4
kill -9 $!
sleep 1
cat results/slow.txt

snakemake -s Snakefile.slow --cores 1 # fails

snakemake -s Snakefile.slow --cores 1 --rerun-incomplete # fails

sleep 6
cat results/slow.txt

snakemake -s Snakefile.slow --unlock

snakemake -s Snakefile.slow --cores 1 --rerun-incomplete --quiet

cat results/slow.txt

snakemake -s Snakefile.prefix --cores 1 --quiet

cat results/silent.txt

snakemake -s Snakefile.strict --cores 1 --quiet 2>&1 | grep -E 'Error in rule|exit status' | sort -u

ls results/strict.txt || true
