#!/bin/bash
#SBATCH --job-name=first_job
#SBATCH --account=project_demo
#SBATCH --partition=small
#SBATCH --time=00:05:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=500M
#SBATCH --output=first_job_%j.out

echo "Running on $(hostname)"
echo "Job $SLURM_JOB_ID has $SLURM_CPUS_PER_TASK CPUs"
zcat data/sampleA_R1.fastq.gz | wc -l
