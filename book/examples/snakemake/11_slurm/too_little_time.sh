#!/bin/bash
#SBATCH --job-name=too_long
#SBATCH --account=project_demo
#SBATCH --time=00:00:01
#SBATCH --output=too_long_%j.out

echo "This job asked for too little time"
sleep 300
