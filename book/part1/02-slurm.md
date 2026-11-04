# Asking for resources with SLURM {#sec-slurm}

On a cluster, you don't start heavy programs yourself. You describe a **job**, and the scheduler starts it on a suitable node when one is free. The scheduler used on most academic clusters,
including CSC's, is called **SLURM**. Snakemake will talk to SLURM for you later, but you can only understand what it does, and find out why something went wrong, if you know what SLURM does. So we
start by using it by hand.

All output in this chapter is from the mini cluster described in @sec-running-the-examples, which has real SLURM with one node. The example is in `book/examples/snakemake/11_slurm/`.

## What the cluster looks like

`sinfo` shows the partitions and the state of their nodes:

```text
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
small*       up 3-00:00:00      1   idle localhost
large        up 3-00:00:00      1   idle localhost
```

A **partition** is a group of nodes with its own rules, such as a maximum run time. The `*` marks the default, and `idle` means that the node has nothing to do. On a real cluster, this list is much longer, with
states such as `mix` (partly used), `alloc` (fully used) and `drain` (being taken out of service).

Each cluster has its own partitions. On Puhti, there are for example `small`, `large`, `longrun`, `hugemem` and `gpu`. The values in this pipeline's `config.yaml` refer to those names, so if you run on another
cluster, those are what you need to change (@sec-setup).

## Your first job script

A **job script** is a shell script with instructions for SLURM at the top:

```bash
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
```

To the shell, lines starting with `#` are comments. SLURM reads the `#SBATCH` lines at the top as options:

| Option | Meaning |
|--------|---------|
| `--job-name` | A name, so you can recognise the job |
| `--account` | The project that pays for the computing time |
| `--partition` | Which group of nodes |
| `--time` | The maximum run time, as `hours:minutes:seconds` or `days-hours:minutes:seconds` |
| `--cpus-per-task` | How many CPU cores |
| `--mem` | How much memory in total, like `500M` or `64G` |
| `--output` | Where stdout and stderr go. `%j` becomes the job number |
| `--gres` | Other resources. On Puhti: `--gres=nvme:100` asks for 100 GB of fast local disk |

You submit it with `sbatch`, which answers immediately with the job's number. Your terminal is free again while the job waits and runs:

```text
$ sbatch first_job.sh
Submitted batch job 1
```

The result ends up in the output file:

```text
$ cat first_job_*.out
Running on localhost
Job 1 has 2 CPUs
160
```

The job starts in the folder where you ran `sbatch`, and inherits your environment variables. Since all nodes share the disks, it sees the same files that you do.

## Watching your jobs

`squeue` lists jobs that are waiting or running. The output below comes from a job submitted just before:

```text
$ squeue --format="%.8i %.10P %.10j %.2t %.8M %.6D %R"
   JOBID  PARTITION       NAME ST     TIME  NODES NODELIST(REASON)
       5      small    waiting PD     0:00      1 (None)
```

Add `-u $USER` on a real cluster to see only your own jobs, or `--me` for short. The column `ST` has the state: `PD` is pending, and `R` is running. The last column shows the node when it runs, and otherwise a reason for waiting.
Here are the reasons that you will see most:

| Reason | Meaning |
|--------|---------|
| `Priority` | Other jobs are ahead of yours |
| `Resources` | Your job is next, but no node has room yet |
| `QOSMaxJobsPerUserLimit` | You reached a limit on running jobs |
| `AssocGrpBillingMinutes` | Your project ran out of computing time |

`scontrol show job` gives every detail of a job:

```text
$ scontrol show job $JOB | grep -E 'JobName|JobState|Partition=|NumCPUs|TimeLimit' | cut -c1-70
JobId=5 JobName=waiting
   JobState=PENDING Reason=None Dependency=(null)
   RunTime=00:00:00 TimeLimit=00:05:00 TimeMin=N/A
   Partition=small AllocNode:Sid=localhost:298
   NumNodes=1 NumCPUs=1 NumTasks=1 CPUs/Task=1 ReqB:S:C:T=0:0:*:*
```

`scancel` stops a job. Use `scancel -u $USER` with care, as it stops all of your jobs:

```text
$ scancel $JOB
$ sacct -j $JOB -X --format=JobID,JobName,State,ExitCode
JobID           JobName      State ExitCode 
------------ ---------- ---------- -------- 
5               waiting CANCELLED+      0:0
```

## After the job: `sacct` tells you what happened

`squeue` forgets a job soon after it ended, and `sacct` keeps the records. It is the most useful command for understanding failures:

```text
$ sacct -X --format=JobID,JobName,Partition,State,ExitCode,Elapsed,AllocCPUS,ReqMem | tail -n 1
1             first_job      small  COMPLETED      0:0   00:00:00          2       500M
```

`-X` leaves out the internal steps of a job. By default `sacct` only shows jobs from today, and `-S 2026-11-01` asks for an earlier start date. On a real cluster, also ask for the memory that the job really used:

```bash
sacct -j 123456 --format=JobID,JobName,State,ExitCode,Elapsed,Timelimit,ReqMem,MaxRSS
```

The state column tells you what to do next:

| State | Meaning | What to do |
|-------|---------|------------|
| `COMPLETED` | Finished with exit code 0 | Nothing |
| `FAILED` | The script ended with an error | Read the output file |
| `OUT_OF_MEMORY` | It exceeded its memory | Ask for more `--mem` |
| `TIMEOUT` | It exceeded its time limit | Ask for more `--time`, or check whether it hung |
| `CANCELLED` | Someone stopped it | Check who, and whether it was you |
| `NODE_FAIL` | The node died | Submit it again |
| `PENDING`, `RUNNING` | Not done yet | Wait |

### What a time limit looks like

Let's provoke one. This job asks for one second and wants to run for five minutes:

```bash
#!/bin/bash
#SBATCH --job-name=too_long
#SBATCH --account=project_demo
#SBATCH --time=00:00:01
#SBATCH --output=too_long_%j.out

echo "This job asked for too little time"
sleep 300
```

```text
$ sbatch too_little_time.sh
Submitted batch job 6

$ sacct -X --name=too_long --format=JobID,JobName,State,ExitCode,Elapsed,Timelimit
JobID           JobName      State ExitCode    Elapsed  Timelimit 
------------ ---------- ---------- -------- ---------- ---------- 
6              too_long    TIMEOUT      0:0   00:01:04   00:01:00
```

SLURM rounded the limit up to one minute, and killed the job shortly after. See the exit code: `0:0`. **The exit code alone doesn't tell you that a job failed.** The state does.

### What running out of memory looks like

This mini cluster doesn't limit memory, because it runs without Linux's cgroups, so we can't show it here. On Puhti and most production clusters, a job that exceeds its `--mem` gets a program killed by the system.
You then usually find `OUT_OF_MEMORY` in `sacct`, and a line in the job's output with the words `oom-kill` or `Killed`.

Now an important detail for later. In this case, the system normally kills the biggest process in the job. That's usually your tool, and the rest of the job script keeps running. This detail will matter in @sec-cluster.

## Many similar jobs: arrays

For the same work on many samples, an **array job** avoids writing many scripts. SLURM runs one copy per index, and gives it the variable `$SLURM_ARRAY_TASK_ID`:

```bash
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
```

```text
$ sbatch array_job.sh
Submitted batch job 2

$ cat array_*.out
Task 0 works on sampleA: 160 lines
Task 1 works on sampleB: 240 lines
Task 2 works on sampleC: 100 lines

$ sacct -X --format=JobID%14,JobName,State,ExitCode | tail -n 3
           2_0  array_job  COMPLETED      0:0 
           2_1  array_job  COMPLETED      0:0 
           2_2  array_job  COMPLETED      0:0
```

Arrays work well for one step on many samples. But when one step has to wait for another across hundreds of samples, you would need job dependencies, and that's where managing this by hand stops being fun. It is why we use Snakemake.

## Working interactively

For debugging, you sometimes want a terminal on a compute node. Ask for one like this:

```bash
srun --account=project_2009831 --partition=small --time=01:00:00 --mem=8G --cpus-per-task=2 --pty bash
```

Once SLURM finds room, your prompt moves to a compute node, and you can run commands by hand. Type `exit` to give it back. CSC also has a shortcut called `sinteractive`. This wasn't run for this book, since a terminal session can't be recorded by our examples.

Use this when a rule fails and you want to rerun its command yourself. It is much better than doing that on the login node.

## How to choose your resources

Nobody knows the right values in advance, and it depends on your data. Some advice:

- **Start from something similar.** A benchmark file from an earlier project tells you more than any rule of thumb.
- **Look at what you really used.** `sacct` shows `MaxRSS` for memory and `Elapsed` for time. Compare them with your request.
- **Don't ask for much more than you need.** Bigger requests wait longer, and on most systems you pay for what you reserve, whether you use it or not.
- **Time limits decide the partition.** On Puhti, jobs longer than three days need `longrun`.
- **More cores don't always help.** Many tools stop getting faster at some point, while the queue time keeps growing.

This pipeline's answer to the problem is to start with a modest request, and go up when a job fails. @sec-pipeline-patterns describes that.

## Summary

| Command | Purpose |
|---------|---------|
| `sinfo` | Partitions and nodes |
| `sbatch script.sh` | Submit a job |
| `squeue --me` | Your waiting and running jobs |
| `scontrol show job ID` | All details of a job |
| `scancel ID` | Stop a job |
| `sacct -j ID` | What happened to a finished job |
| `srun --pty bash` | A terminal on a compute node |
