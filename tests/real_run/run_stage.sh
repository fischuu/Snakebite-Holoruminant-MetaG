#!/usr/bin/env bash
# Run one target of the pipeline and keep a record of the run. Call it in the project folder.
# Usage: run_stage.sh <target> [more Snakemake options]
# Every call writes a new folder book_run/<target>/<date>, so a failed attempt stays on record.
set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: run_stage.sh <target> [more Snakemake options]" >&2
    exit 2
fi
if [ ! -f run_Snakebite-Holoruminant-MetaG.sh ]; then
    echo "ERROR: run this in the project folder that setup_project.sh created" >&2
    exit 2
fi

target=$1
shift
wrapper=run_Snakebite-Holoruminant-MetaG.sh
pipeline="$(sed -nE 's/^pipeline_folder:[[:space:]]*"?([^"#]*)"?.*/\1/p' config/config.yaml)"
record="book_run/$target/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$record"

start=$(date +%Y-%m-%dT%H:%M:%S)
{
    echo "target: $target"
    echo "more options: $*"
    echo "start: $start"
    echo "host: $(hostname)"
    echo "pipeline commit: $(git -C "$pipeline" rev-parse HEAD 2>/dev/null)"
    echo "changed files in the pipeline folder: $(git -C "$pipeline" status --short 2>/dev/null | grep -vc '^??')"
} > "$record/info.txt"

echo "Dry run of $target, this tells you what is about to happen ..."
if ! bash "$wrapper" "$target" --dry-run --printshellcmds "$@" > "$record/dryrun.txt" 2>&1; then
    tail -n 30 "$record/dryrun.txt"
    echo "The dry run failed, so nothing was started. Everything it printed: $record/dryrun.txt"
    echo "dry run failed" >> "$record/info.txt"
    exit 1
fi
grep -A200 '^Job stats:' "$record/dryrun.txt" | sed '/^$/q'

# Snakemake removes the job logs of successful jobs unless it is told not to
bash "$wrapper" "$target" --slurm-keep-successful-logs "$@" 2>&1 | tee "$record/snakemake.log"
status=${PIPESTATUS[0]}
end=$(date +%Y-%m-%dT%H:%M:%S)
{
    echo "end: $end"
    echo "exit status: $status"
} >> "$record/info.txt"

# One line per job and job step. The job steps hold the memory that was really used (MaxRSS).
sacct -u "$(id -un)" -S "$start" -E "$end" -P \
    --format=JobID,JobName%40,Comment%120,Partition,AllocCPUS,ReqMem,MaxRSS,Elapsed,Timelimit,State,ExitCode,NodeList \
    > "$record/sacct.tsv" 2> "$record/sacct.err"
[ -s "$record/sacct.err" ] || rm -f "$record/sacct.err"

# The folder of a job log names its rule, in case the cluster's sacct doesn't store the comment
if [ -d .snakemake/slurm_logs ]; then
    find .snakemake/slurm_logs -type f -newermt "$start" | sort > "$record/job_logs.txt"
fi
if [ -d results ]; then
    find results -type f -printf '%s\t%p\n' | sort -t "$(printf '\t')" -k2 > "$record/result_files.tsv"
fi

echo
if [ "$status" -eq 0 ]; then
    echo "$target finished. The record of this run is in $record"
else
    echo "$target failed with exit status $status. The record of this run is in $record"
    grep -E '^Error in rule|^RuleException|^Exiting because' "$record/snakemake.log" | sort | uniq -c | head -n 20
fi
exit "$status"
