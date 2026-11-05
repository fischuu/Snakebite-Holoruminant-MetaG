# Running on the cluster {#sec-cluster}

Everything so far ran on one machine. Now Snakemake gets to do what it was made for: sending each job to SLURM. You will see that your rules don't change at all. The example is in
`book/examples/snakemake/12_cluster/`, and everything in this chapter ran on the mini cluster with real SLURM.

## How it works

Snakemake itself stays on the login node, and acts as a dispatcher. For each job it is ready to start, it runs `sbatch`. It then checks the status of the jobs every so often, and when a job has finished, it starts those that were waiting for it.

Inside each SLURM job runs **another Snakemake**. It reads your whole Snakefile again, and runs only the one job it was sent for. So there are two kinds of Snakemake processes, and they need the same files and settings. This will become important at the end of this chapter.

## Profiles: settings for the cluster

Cluster options would make for long command lines, so they go in a **profile**: a folder with a `config.yaml`, where each option of the command line can be written down:

```yaml
executor: slurm
jobs: 10
latency-wait: 5
default-resources:
    slurm_account: "project_demo"
    slurm_partition: "small"
    runtime: 10
    mem_mb: 200
    cpus_per_task: 1
```

| Setting | Meaning |
|---------|---------|
| `executor: slurm` | Submit jobs through SLURM. This needs the plugin `snakemake-executor-plugin-slurm` |
| `jobs: 10` | At most 10 jobs at once, waiting ones included |
| `latency-wait: 5` | Wait this many seconds for files to appear on the shared disk |
| `default-resources` | Used by every rule that doesn't say otherwise |

`--profile profile` loads it. With a cluster, `--jobs` replaces `--cores`.

## The rules stay the same

```python
SAMPLES = ["sampleA", "sampleB", "sampleC"]


rule all:
    input:
        "results/summary.txt",


rule count_reads:
    input:
        "data/{sample}_R1.fastq.gz",
    output:
        "results/{sample}.txt",
    threads: 2
    resources:
        mem_mb=300,
        cpus_per_task=2,
        runtime=5,
    shell:
        "zcat {input} | wc -l > {output}"


rule summary:
    input:
        expand("results/{sample}.txt", sample=SAMPLES),
    output:
        "results/summary.txt",
    shell:
        "paste {input} > {output}"
```

Only `resources:` has grown. Here is how those values reach SLURM:

| In the rule | Becomes in `sbatch` |
|-------------|---------------------|
| `resources: mem_mb=300` | `--mem 300` |
| `resources: runtime=5` | `-t 5` (minutes) |
| `resources: cpus_per_task=2` | `--cpus-per-task=2` |
| `resources: slurm_partition="small"` | `-p small` |
| `resources: slurm_account="x"` | `-A x` |
| `resources: gres="nvme:10"` | `--gres=nvme:10` |

Set both `threads:` and `cpus_per_task`, since `threads` only tells Snakemake and your command how many to use, whereas `cpus_per_task` is what SLURM reserves.

Let's run it:

```text
$ snakemake --profile profile --quiet rules --slurm-keep-successful-logs
Using profile profile for setting default command line arguments.
host: localhost
Building DAG of jobs...
SLURM run ID: f41cde61-c9ba-4ed2-ab8a-110900e1c2df
Using shell: /usr/bin/bash
Provided remote nodes: 10
Job stats:
job            count
-----------  -------
all                1
count_reads        3
summary            1
total              5

Select jobs to execute...
Execute 3 jobs...
Job 4 has been submitted with SLURM jobid 17 (log: .snakemake/slurm_logs/rule_count_reads/sampleC/17.log).
Job 3 has been submitted with SLURM jobid 18 (log: .snakemake/slurm_logs/rule_count_reads/sampleB/18.log).
Job 2 has been submitted with SLURM jobid 19 (log: .snakemake/slurm_logs/rule_count_reads/sampleA/19.log).
[...]
Job 1 has been submitted with SLURM jobid 20 (log: .snakemake/slurm_logs/rule_summary/20.log).
[...]
5 of 5 steps (100%) done

$ sacct -X --format=JobID,Comment%24,Partition,AllocCPUS,ReqMem,State,ExitCode | tail -n 4
17           rule_count_reads_wildca+      small          2       300M  COMPLETED      0:0 
18           rule_count_reads_wildca+      small          2       300M  COMPLETED      0:0 
19           rule_count_reads_wildca+      small          2       300M  COMPLETED      0:0 
20                       rule_summary      small          1       200M  COMPLETED      0:0
```

Each `count_reads` job got the 2 CPUs and 300 MB it asked for, and `summary` got the default values from the profile. The name of the rule is in SLURM's `Comment` field, since the job name is a random run ID. To see it in `sacct`, ask for `Comment`, and widen the column as needed.

Notice that `rule all` wasn't submitted. It has no command, so it runs locally. You can also mark quick rules with `localrules: myrule` to keep them off the queue.

## Where to look: three kinds of logs

There are now three places where messages end up, and each has something the others don't:

| File | What it holds |
|------|---------------|
| `.snakemake/log/<date>.snakemake.log` | The dispatcher: what was submitted and when, and what failed |
| `.snakemake/slurm_logs/rule_<name>/<wildcards>/<jobid>.log` | One SLURM job, including the inner Snakemake and any crash of it |
| The rule's own `log:` | What the tool said |

Normally you start with the last one. If it is empty or stops suddenly, read the SLURM log, which shows whether the job was killed. The executor plugin removes the SLURM logs of successful jobs by default, and `--slurm-keep-successful-logs` keeps them.

## When a job fails: retries and attempts

A job can fail because it needs more resources. Snakemake can then try again, asking for more each time. Here is a rule that simulates this. It fails whenever it gets less than 400 MB:

```python
def more_memory(wildcards, attempt):
    return 200 * attempt


rule needs_more_memory:
    output:
        "results/retried.txt",
    resources:
        mem_mb=more_memory,
        attempt=lambda wildcards, attempt: attempt,
    shell:
        """
        echo "Attempt {resources.attempt} with {resources.mem_mb} MB"
        if [ {resources.mem_mb} -lt 400 ]; then
            echo "Not enough memory" >&2
            exit 1
        fi
        echo "Succeeded with {resources.mem_mb} MB" > {output}
        """
```

With the command-line option `--retries 2`, this is what happens:

```text
$ snakemake --snakefile Snakefile.retries --profile profile --retries 2 --quiet rules
[...]
Job 1 has been submitted with SLURM jobid 21 (log: .snakemake/slurm_logs/rule_needs_more_memory/21.log).
Trying to restart job 1.
Job 1 has been submitted with SLURM jobid 22 (log: .snakemake/slurm_logs/rule_needs_more_memory/22.log).
[...]

$ cat results/retried.txt
Succeeded with 400 MB

$ sacct -X --format=JobID,Comment%26,ReqMem,State,ExitCode | tail -n 2
21               rule_needs_more_memory       200M     FAILED      1:0 
22               rule_needs_more_memory       400M  COMPLETED      0:0
```

This is exactly what you want: the first SLURM job failed with 200 MB, and Snakemake submitted a second one with 400 MB.

## A trap: `retries:` in a rule behaves differently {#sec-retries-trap}

Snakemake also has a directive to set retries per rule, and this seems like the same thing. We add `retries: 2` to the rule and run it without the command-line option:

```text
$ sed -i 's/^    resources:$/    retries: 2\n    resources:/' Snakefile.retries
$ snakemake --snakefile Snakefile.retries --profile profile --quiet rules --slurm-keep-successful-logs
[...]
Job 1 has been submitted with SLURM jobid 23 (log: .snakemake/slurm_logs/rule_needs_more_memory/23.log).
[...]

$ cat results/retried.txt
Succeeded with 400 MB

$ sacct -X --format=JobID,Comment%26,ReqMem,State,ExitCode | tail -n 1
23               rule_needs_more_memory       200M  COMPLETED      0:0

$ grep -c 'Trying to restart' .snakemake/slurm_logs/rule_needs_more_memory/*.log
.snakemake/slurm_logs/rule_needs_more_memory/21.log:0
.snakemake/slurm_logs/rule_needs_more_memory/23.log:1
```

Look closely. The result says "Succeeded with 400 MB", but SLURM's record says that job 23 had **200 MB** and that it was one single job. The message "Trying to restart" is inside its SLURM log.

What happened? Remember that each SLURM job runs its own Snakemake, which reads the Snakefile too, and therefore also sees `retries: 2`. When the command failed, this inner Snakemake restarted it inside the same SLURM job, with `attempt` set to 2. So the command was told that it has 400 MB, while SLURM still only gave it 200 MB.

This has real consequences on a production cluster:

- The retry doesn't get more memory or CPUs, even though `{resources.mem_mb}` and `{threads}` now claim that it does. A tool that gets `-t {threads}` starts more threads than it has CPUs for.
- If the tool ran out of memory, the system usually kills only the tool, and the inner Snakemake survives. It then retries in the same too-small job, and probably fails the same way.
- Only when all inner attempts have failed does the SLURM job end as `FAILED`. Only then does the outer Snakemake submit a new, bigger job, which can repeat this. A rule with three retries can run up to many times more often than intended, and use a lot of allocation.
- If SLURM kills the whole job, for example at the time limit, there is no inner Snakemake left. Then the outer one resubmits right away with more resources, as you would expect.

The cure follows from the explanation. The directive should only count in the outer Snakemake. In the Snakefile, `workflow.remote_exec` tells you that you are inside a job, and the attribute of a rule that holds its retries is called `restart_times`:

```python
# Inside a running SLURM job, Snakemake must not retry: the job has its resources already
if workflow.remote_exec:
    for rule_object in workflow.rules:
        rule_object.restart_times = 0
```

With this, the rule behaves as you would expect:

```text
$ snakemake results/retried.txt --snakefile Snakefile.fixed --profile profile --quiet rules
[...]
Job 0 has been submitted with SLURM jobid 24 (log: .snakemake/slurm_logs/rule_needs_more_memory/24.log).
Trying to restart job 0.
Job 0 has been submitted with SLURM jobid 25 (log: .snakemake/slurm_logs/rule_needs_more_memory/25.log).
[...]

$ sacct -X --format=JobID,Comment%26,ReqMem,State,ExitCode | tail -n 2
24               rule_needs_more_memory       200M     FAILED      1:0 
25               rule_needs_more_memory       400M  COMPLETED      0:0
```

These results come from Snakemake 9.11.6 with version 2.8.0 of the SLURM plugin. Other versions may differ. To find out what your own setup does, search your SLURM logs:

```bash
grep -l 'Trying to restart' .snakemake/slurm_logs/*/*.log .snakemake/slurm_logs/*/*/*.log
```

Every file listed is a retry that stayed inside one SLURM job. This pipeline had exactly this problem until version 0.4.68, and @sec-pipeline-patterns shows how it sets retries now.

## A few more options for the cluster

| Option | Purpose |
|--------|---------|
| `--jobs N` | How many jobs at once |
| `--latency-wait N` | Seconds to wait for output files |
| `--keep-going` | Continue with other jobs after a failure, instead of stopping |
| `--rerun-incomplete` | Redo the files of interrupted jobs |
| `--slurm-keep-successful-logs` | Keep SLURM logs of finished jobs |
| `--scheduler greedy` | A faster way of choosing the next jobs, which helps with large DAGs |
| `--max-jobs-per-second N` | Limit how quickly jobs are submitted, to go easy on the scheduler |

`--keep-going` deserves a mention. By default, Snakemake stops submitting new jobs after a failure, and waits for the running ones. On a large run, you often prefer that all the independent work continues overnight, so you can look at the failures in the morning.

## Where Snakemake itself should run

Snakemake must keep running as long as the workflow does, for days if necessary. Options are:

- **A tmux session on the login node.** It uses very little CPU, and this is how the pipeline is usually run. Some clusters limit how long you can run processes on a login node, so check your centre's rules.
- **A long SLURM job of its own**, with few resources. The dispatcher then runs on a compute node, and submits the other jobs from there.

## Summary

- Snakemake stays on the login node, and submits each job with `sbatch`. Inside each job, another Snakemake runs the one job.
- A profile holds the cluster options, and `resources:` becomes SLURM options.
- `sacct` with `Comment` shows the rule behind each job.
- `--retries` submits a bigger job, whereas the directive `retries:` also retries inside the running job, unless you switch that off.
