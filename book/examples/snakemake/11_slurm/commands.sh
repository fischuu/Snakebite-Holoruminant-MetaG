sinfo

sbatch first_job.sh

sleep 4
sacct -X --format=JobID,JobName,Partition,State,ExitCode,Elapsed,AllocCPUS,ReqMem | tail -n 1

cat first_job_*.out

sbatch array_job.sh

sleep 4
cat array_*.out

sacct -X --format=JobID%14,JobName,State,ExitCode | tail -n 3

JOB=$(sbatch --parsable --wrap "sleep 120" --account=project_demo --job-name=waiting --time=00:05:00)
sleep 2
squeue --format="%.8i %.10P %.10j %.2t %.8M %.6D %R"
scontrol show job $JOB | grep -E 'JobName|JobState|Partition=|NumCPUs|TimeLimit' | cut -c1-70
scancel $JOB
sleep 2
sacct -j $JOB -X --format=JobID,JobName,State,ExitCode

sbatch too_little_time.sh

sleep 75
sacct -X --name=too_long --format=JobID,JobName,State,ExitCode,Elapsed,Timelimit
