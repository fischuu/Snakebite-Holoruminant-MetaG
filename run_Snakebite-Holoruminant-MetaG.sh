#!/usr/bin/env bash

# Set the project relevant paths
################################################################################
projectFolder="/scratch/project_2009831/Pipe_test"
configFile="${projectFolder}/config/config.yaml"

# Setup the server profile. You can copy the default profile and adjust it to your hpc.
# Check that the generic command meets the requirements from your (slurm) executor.
# It is recommended to copy the Profile folder to a new folder with the name of
# your cluster
################################################################################
Profile=$projectFolder/config/profiles/Puhti

# Make Snakemake available. Here is an example, how it would be loaded with the
# module system, but other systems might have it available per standard installation.
# In that case you can comment out the follwing line
################################################################################
module load snakemake/9.11.6

# For use with Apptainer, set these variables
################################################################################
export APPTAINER_TMPDIR="/scratch/project_2009831/tmp"
export APPTAINER_CACHEDIR="/scratch/project_2009831/tmp"
mkdir -p $APPTAINER_TMPDIR
mkdir -p $APPTAINER_CACHEDIR

# Snakemake cache
# Per default, snakemake writes caches to <home>/.cache/snakemake/... which can
# be rather limited on HPC and could lead to unexpected out-of-discspace errors.
# You can set this variable to adjust the path for the cache
################################################################################
# export XDG_CACHE_HOME="<filepath>"

# Create the rulegraph
################################################################################
#snakemake -s $pipelineFolder/workflow/Snakefile \
#          --configfile $projectFolder/config/config.yaml \
#          --rulegraph | dot -T png > $projectFolder/workflow.png


# Helper: read YAML value (simple key: value, no nesting)
################################################################################
read_yaml() {
    local key="$1"
    local file="$2"
    grep -E "^[[:space:]]*${key}:" "$file" \
        | sed -E "s/^[^:]+:[[:space:]]*//" \
        | tr -d '"'
}

# Helper: Extract pipeline_folder from pipeline config
################################################################################
pipelineFolder="$(read_yaml pipeline_folder "$configFile")"
metaspades_slots="$(read_yaml metaspades_slots "$configFile")"

if [[ -z "$pipelineFolder" ]]; then
    echo "ERROR: pipeline_folder not defined in $pipelineConfigPath" >&2
    exit 1
fi

if [[ -z "$metaspades_slots" ]]; then
    echo "ERROR: metaspades_slots not defined in $pipelineConfigPath" >&2
    exit 1
fi

echo "config file      : ${configFile}"
echo "Project folder   : ${projectFolder}"


# Run the pipeline (singularity/apptainer)
# Important adjustments: 
# --jobs, how many parallel jobs do you allow on your system for this project
# --singularity-args, are the important folders and paths bound to the containers? If you are unsure, go with the defaults and check for errors
################################################################################
mkdir -p slurm_out
mkdir -p $projectFolder/tmp

# I removed this part:
#           --resources high_io_intense_parallel=20 \
# Add it back in, when you know why it suddenly threw an error

snakemake -s $pipelineFolder/workflow/Snakefile \
          --jobs 150 \
          --use-singularity \
          --configfile $projectFolder/config/config.yaml \
          --profile $Profile \
          --singularity-args "-B /scratch,/projappl,/users,/dev/shm:/dev/shm,/run,$projectFolder/tmp:/tmp" \
          --singularity-prefix $projectFolder/docker_images/ \
          --latency-wait 60 \
          --scheduler greedy \
          --resources metaspades_slots=$metaspades_slots \
          --restart-times 0 \
          --retries 0  \
          $@
