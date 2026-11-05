# Logs, benchmarks, threads and resources {#sec-logs-resources}

So far our rules have printed their messages to the screen. On a cluster there is no screen, and many jobs run at once. This
chapter adds what a production rule needs: a place for its messages, a record of what it used, and a statement of what it needs.
The example is in `book/examples/snakemake/07_logs_threads/`.

## A complete rule

```python
rule sort_reads:
    """Sort the reads by sequence, in parallel"""
    input:
        "data/{sample}_R1.fastq.gz",
    output:
        "results/{sample}.txt",
    log:
        "logs/{sample}.log",
    benchmark:
        "benchmarks/{sample}.tsv",
    threads: 2
    resources:
        mem_mb=500,
        runtime=10,
    shell:
        """
        exec > {log} 2>&1
        echo "Sorting {wildcards.sample} with {threads} threads and {resources.mem_mb} MB"
        zcat {input} | paste - - - - | sort --parallel={threads} -S {resources.mem_mb}M -k 2 > {output}
        sleep 2
        echo "Done"
        """
```

Most rules in this pipeline have exactly this shape.

## `log:` is where messages go

The `log:` directive names a file for the job's messages. It has to contain the same wildcards as the output, because each job
needs its own log. Snakemake doesn't redirect anything on its own: the rule itself has to write to the file. Here, the line
`exec > {log} 2>&1` from @sec-linux does that for all commands that follow.

Log files differ from outputs in one important way: **a log file survives when the job fails**, whereas Snakemake deletes the
output files of a failed job, since they may be broken. So your log is what you have to work with after a failure:

```text
$ cat logs/sampleA.log
Sorting sampleA with 2 threads and 500 MB
Done
```

You will find three ways of writing to logs in this pipeline, and it is useful to know why:

```bash
# 1. Everything from here on goes to the log
exec > {log} 2>&1

# 2. Only messages of the tool go to the log, because its stdout is the result
exec 2> {log}
zcat {input} | bgzip > {output}

# 3. A log per attempt, kept in place when the attempt fails
try_log={log}.try{resources.attempt}
exec > "$try_log" 2>&1
...
mv "$try_log" {log}
```

The third form keeps the log of each failed attempt under its own name, such as `drep.log.try1`, and only a successful attempt
becomes the plain `drep.log`. @sec-cluster explains attempts.

## `benchmark:` measures what a job used

The `benchmark:` directive names a file where Snakemake stores what the job used. It repeats the measurement every few seconds
and keeps the maximum:

```text
$ cut -f 1,2,3,10 benchmarks/sampleA.tsv
s	h:m:s	max_rss	cpu_time
2.0163	0:00:02	4.63	0.00
```

The file has more columns, and the end of `docs/06-Details.md` lists them all. The two that you will use most:

- `s` is the wall-clock time in seconds.
- `max_rss` is the peak memory in MB that the process really held in RAM.

Very short jobs may show `0` or `NA` here, because the measurement didn't catch them. On a real project these files tell you how to
set the resources: if a rule that requests 100 GB peaks at 12 GB, you are wasting allocation and queue time. The pipeline's reports
gather these files into tables for that purpose (@sec-module-report).

## `threads:` says how many cores a job can use

`threads:` tells Snakemake how many CPU cores a job needs. In the command, `{threads}` gives the number that it really got. Always
pass it to the tool, because Snakemake doesn't limit what a program does: if the tool starts 40 threads on its own while the job
asks for 2, the job will still use 40, slow down its neighbours, and might get killed.

Snakemake uses this number for its planning. If you allow `--cores 4`, two jobs with 2 threads each run at once. If you allow fewer
cores than a rule claims, it scales the rule down:

```text
$ snakemake --cores 1 --forceall --quiet rules
[...]
Provided cores: 1 (use --cores to define parallelism)
Rules claiming more threads will be scaled down.
[...]
```

You can change the number for a rule from the command line, which is handy when you try things out on a cluster. Remember to
put the target first, as discussed in @sec-wildcards:

```text
$ snakemake results/sampleA.txt --cores 4 --forceall --dry-run --set-threads sort_reads=4 | grep -E 'threads|resources'
    threads: 4
    resources: tmpdir=<TBD>, mem_mb=500, mem_mib=477, runtime=10
```

## `resources:` says what else it needs

`resources:` holds anything else a job requires. Two names have a defined meaning on clusters:

| Name | Meaning |
|------|---------|
| `mem_mb` | Memory in megabytes |
| `runtime` | Maximum run time in minutes |

There are others for specific systems, such as `slurm_partition`, `slurm_account` and `gres`, and @sec-cluster covers them.

Run locally, these are only used for planning: `--resources mem_mb=1000` lets Snakemake start only as many jobs as fit within 1000 MB
in total. You can also make up your own. The pipeline uses this to limit how many metaSPAdes jobs run at the same time, because
these put a heavy load on a shared disk. The rule says:

```python
    resources:
        metaspades_slots=1,
```

and the run script says how many such slots exist in total:

```bash
snakemake ... --resources metaspades_slots=$metaspades_slots
```

Snakemake then never starts more metaSPAdes jobs at once than that number.

### Resources that depend on the attempt

A resource can be a function, and it is called with the wildcards and the number of the attempt. This makes it possible to ask for
more the second time:

```python
    resources:
        mem_mb=lambda wildcards, attempt: 8000 * attempt,
```

This idea is the basis of the pipeline's resource escalation, and @sec-pipeline-patterns describes how it works there.

## The anatomy of a rule in this pipeline

With that, you can read a real rule. Here is one from the pipeline, with a comment on each directive:

```python
rule assemble__drep__catalogue:                 # module__tool__step
    """Concatenate the dereplicated genomes into the MAG catalogue"""
    input:
        MAG_GENOMES,                            # a path constant from folders.smk
    output:
        MAG_CATALOGUE,
    log:
        DREP / "dereplicated_genomes.log",
    benchmark:
        DREP / "benchmark/join_genomes.tsv"
    container:
        docker["assemble"]                      # the software, see the chapter on containers
    threads: esc("cpus", "assemble__drep__catalogue")   # from the resource sets
    resources:
        runtime=esc("runtime", "assemble__drep__catalogue"),
        mem_mb=esc("mem_mb", "assemble__drep__catalogue"),
        cpus_per_task=esc("cpus", "assemble__drep__catalogue"),
        slurm_partition=esc("partition", "assemble__drep__catalogue"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__drep__catalogue')['nvme']}",
        attempt=esc("attempt", "assemble__drep__catalogue"),
    shell:
        """
        exec 2> {log}
        debug "genomes={input} threads={threads} catalogue={output}"
        zcat {input}/*.fa.gz | bgzip -l 9 -@ {threads} > {output}
        """
```

Don't worry about `esc` yet. It looks up a value for this rule in the configured resource sets. The command itself is the last line,
and everything else is there to make it work on a cluster.

## Summary

- `log:` gives each job a file for messages, which survives a failure.
- `benchmark:` records time and memory.
- `threads:` and `resources:` state what a job needs, and you pass `{threads}` to the tool.
- Resources can be functions of the attempt.
