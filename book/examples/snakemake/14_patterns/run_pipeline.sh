#!/usr/bin/env bash
# A small version of run_Snakebite-Holoruminant-MetaG.sh: one place for all options of a run.
export PIPELINE_DEBUG="${PIPELINE_DEBUG:-0}"

snakemake -s workflow/Snakefile \
          --configfile config/config.yaml \
          --profile config/profiles/minicluster \
          --restart-times 0 \
          --retries 0 \
          "$@"
