#!/usr/bin/env bash
# Run targets of the real pipeline in the project folder. Usage: run.sh <project> <target> [more options]
# One job at a time, because Docker has 8 GB of memory here.
project=$1; shift
pipeline="$(cd "$(dirname "$0")/../../.." && pwd)"
export PROJECT="$project" PIPELINE="$pipeline" PATH="$pipeline/book/examples/real_tools/shim:$PATH"
cd "$project" || exit 1
# Set SNAKEMAKE if the snakemake to use isn't the first one in the PATH
"${SNAKEMAKE:-snakemake}" -s "$pipeline/workflow/Snakefile" \
    --configfile config/config.yaml --cores 8 --jobs 1 --use-singularity --singularity-prefix docker_images \
    --latency-wait 5 --scheduler greedy --printshellcmds "$@"
