snakemake --profile profile --dry-run --quiet rules

snakemake --profile profile --quiet rules --slurm-keep-successful-logs

sacct -X --format=JobID,Comment%24,Partition,AllocCPUS,ReqMem,State,ExitCode | tail -n 4

cat results/summary.txt

ls .snakemake/slurm_logs/rule_count_reads/sampleA/ | sed -E 's/[0-9]+/<jobid>/'

snakemake --snakefile Snakefile.retries --profile profile --retries 2 --quiet rules

cat results/retried.txt

sacct -X --format=JobID,Comment%26,ReqMem,State,ExitCode | tail -n 2

rm results/retried.txt
sed -i 's/^    resources:$/    retries: 2\n    resources:/' Snakefile.retries
snakemake --snakefile Snakefile.retries --profile profile --quiet rules --slurm-keep-successful-logs

cat results/retried.txt

sacct -X --format=JobID,Comment%26,ReqMem,State,ExitCode | tail -n 1

grep -c 'Trying to restart' .snakemake/slurm_logs/rule_needs_more_memory/*.log

rm results/retried.txt
snakemake results/retried.txt --snakefile Snakefile.fixed --profile profile --quiet rules

cat results/retried.txt

sacct -X --format=JobID,Comment%26,ReqMem,State,ExitCode | tail -n 2
