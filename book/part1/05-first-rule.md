# Your first rule {#sec-first-rule}

We start with the smallest useful workflow: counting the reads in one file. The example is in
`book/examples/snakemake/01_first_rule/`.

## The Snakefile

A rule goes in a file called `Snakefile`:

```python
rule count_reads:
    input:
        "data/sampleA_R1.fastq.gz",
    output:
        "results/sampleA_R1.count.txt",
    shell:
        "zcat {input} | wc -l | awk '{{print $1 / 4}}' > {output}"
```

Line by line:

- `rule count_reads:` starts a rule and gives it a name. Names can use letters, numbers and underscores.
- `input:` lists the files the rule needs. Snakemake won't start it until they exist.
- `output:` lists the files the rule promises to create. Snakemake checks this afterwards.
- `shell:` is the command to run.

Indentation matters. Everything that belongs to the rule is indented by four spaces, and the entries under `input:` by
eight. The comma after a file name is optional for one entry, but it is good practice, because you will need it as soon
as there are two.

## How `{input}` and `{output}` work

Before the command runs, Snakemake replaces `{input}` with the input files and `{output}` with the output files. So
the shell runs:

```bash
zcat data/sampleA_R1.fastq.gz | wc -l | awk '{print $1 / 4}' > results/sampleA_R1.count.txt
```

This explains the doubled braces in `{{print $1 / 4}}`. Single braces mean "replace this" to Snakemake, but `awk` needs
real braces. A doubled brace tells Snakemake that you mean a literal brace, so `{{` becomes `{`. You will write this for
every `awk` program and every shell array such as `${{files[@]}}`. @sec-debugging shows what happens if you forget.

Also notice what you don't write: the rule doesn't create the folder `results/`. Snakemake creates the folders of output
files before it starts a job.

## The dry run: always look first

`--dry-run`, or `-n` for short, shows the plan and runs nothing:

```text
$ snakemake --dry-run
host: localhost
Building DAG of jobs...
Job stats:
job            count
-----------  -------
count_reads        1
total              1


[date]
rule count_reads:
    input: data/sampleA_R1.fastq.gz
    output: results/sampleA_R1.count.txt
    jobid: 0
    reason: Missing output files: results/sampleA_R1.count.txt
    resources: tmpdir=<TBD>
[...]
This was a dry-run (flag -n). The order of jobs does not reflect the order of execution.
```

Read this from the top. "Job stats" shows how many jobs of each rule would run. Then each job appears with its files. The
line to look at is `reason`, which says why Snakemake wants to run it: here, the output doesn't exist.

Make the dry run a habit. On a cluster, a mistake can start thousands of jobs or rerun weeks of finished work, and a dry run
costs a few seconds. This pipeline's documentation asks you to do one before every real run, and this book does too.

## Running it

To run it for real, say how many CPU cores Snakemake may use with `--cores`:

```text
$ snakemake --cores 1
Assuming unrestricted shared filesystem usage.
host: localhost
Building DAG of jobs...
Using shell: /usr/bin/bash
Provided cores: 1 (use --cores to define parallelism)
Rules claiming more threads will be scaled down.
Job stats:
job            count
-----------  -------
count_reads        1
total              1

Select jobs to execute...
Execute 1 jobs...

[date]
localrule count_reads:
    input: data/sampleA_R1.fastq.gz
    output: results/sampleA_R1.count.txt
    jobid: 0
    reason: Missing output files: results/sampleA_R1.count.txt
    resources: tmpdir=/tmp
[date]
Finished jobid: 0 (Rule: count_reads)
1 of 1 steps (100%) done
Complete log(s): /scratch/project_demo/examples/01_first_rule/.snakemake/log/<date>.snakemake.log

$ cat results/sampleA_R1.count.txt
40
```

There is the answer: 40 reads. The last line says where Snakemake keeps a copy of everything it printed. These log files
collect in the folder `.snakemake/log/`, and are the first place to look when you want to know what happened last night.

## Running it again

Run the same command again:

```text
$ snakemake --cores 1
Assuming unrestricted shared filesystem usage.
host: localhost
Building DAG of jobs...
Nothing to be done (all requested files are present and up to date).
```

This is the central feature. The output exists and is current, so there is nothing to do. On a cluster this means that you
can simply start a workflow again after anything goes wrong, and it continues where it stopped.

## When does a rule run again?

To decide whether a file is current, Snakemake looks at several things, called **rerun triggers**. The most obvious one
is time: a job reruns if an input is newer than its output. This goes further than you might expect, so let us test it. If
we only update the file's date with `touch`, without changing its content:

```text
$ touch data/sampleA_R1.fastq.gz
$ snakemake --cores 1 --dry-run --quiet
host: localhost
Building DAG of jobs...
Nothing to be done (all requested files are present and up to date).
```

Nothing happens. That file is small, so Snakemake also stored a checksum of it, and saw that the content is the same. Now we
really change the content:

```text
$ cp data/sampleB_R1.fastq.gz data/sampleA_R1.fastq.gz
$ snakemake --cores 1 --dry-run | grep reason
    reason: Updated input files: data/sampleA_R1.fastq.gz

$ snakemake --cores 1 --quiet
[...]
$ cat results/sampleA_R1.count.txt
60
```

So Snakemake recognised the change and updated the result. Be careful with what you conclude from this example: the checksum
comparison only works for small files, and for large files like real FASTQ data, a newer date alone can trigger a rerun.

@sec-reruns covers the other triggers, including changed code and settings, which often surprise people.

You can also force a rerun yourself:

| Option | Effect |
|--------|--------|
| `--force`, `-f` | Rerun the job that produces the target |
| `--forceall`, `-F` | Rerun everything the target depends on |
| `--forcerun rule`, `-R rule` | Rerun all jobs of a rule, and everything downstream |

```text
$ snakemake --cores 1 --forceall --dry-run | grep reason
    reason: Forced execution
```

## Useful options to know now

| Option | Meaning |
|--------|---------|
| `--dry-run`, `-n` | Show the plan, run nothing |
| `--printshellcmds`, `-p` | Also print each command |
| `--cores N`, `-c N` | Use up to N CPU cores |
| `--snakefile FILE`, `-s FILE` | Use another file than `Snakefile` |
| `--quiet rules` | Print less: only the overview of rules and the progress |

`-np` together is the combination you will type most often. It shows the plan with the exact commands, which is the fastest
way to check that a rule does what you intended.

## What Snakemake wrote to your folder

Besides your results, there is now a hidden folder:

```
.snakemake/
    log/        a log file per Snakemake run
    metadata/   what it knows about each output file: code, parameters, input checksums
    locks/      marks that a Snakemake is running in this folder
```

Snakemake keeps here what it needs to decide about reruns. Don't edit it. On the other hand, it is safe to delete the logs, and
this folder doesn't belong in version control.

## Summary

- A rule says how to make output files from input files with a command.
- `{input}` and `{output}` get replaced, and literal braces must be doubled.
- `snakemake -n` shows the plan and `snakemake --cores N` runs it.
- A rerun only does what is missing or out of date.

This rule has one big weakness: it only works for one file. The next chapter fixes that.
