#!/bin/bash
#SBATCH --job-name=array_job
#SBATCH --account=project_demo
#SBATCH --time=00:05:00
#SBATCH --mem=100M
#SBATCH --array=0-2
#SBATCH --output=array_%A_%a.out

samples=(sampleA sampleB sampleC)
sample=${samples[$SLURM_ARRAY_TASK_ID]}
echo "Task $SLURM_ARRAY_TASK_ID works on $sample: $(zcat data/${sample}_R1.fastq.gz | wc -l) lines"
