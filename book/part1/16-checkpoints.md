# Checkpoints: when the plan depends on results {#sec-checkpoints}

Snakemake normally works out all jobs before it runs anything. Sometimes that's impossible, because the number of later jobs depends on what an earlier job finds. A binner decides how many bins it
produces, and you may want to annotate each of them. For this Snakemake has **checkpoints**. The example is in `book/examples/snakemake/13_checkpoints/`.

## The example

```python
rule all:
    input:
        "results/report.txt",


checkpoint make_bins:
    """How many bins this produces is only known after it has run"""
    input:
        "data/sampleA_R1.fastq.gz",
    output:
        directory("results/bins"),
    shell:
        """
        mkdir -p {output}
        zcat {input} | split -l 40 -a 2 -d --additional-suffix=.fastq - {output}/bin_
        """


rule annotate_bin:
    input:
        "results/bins/{bin}.fastq",
    output:
        "results/annotated/{bin}.txt",
    shell:
        "wc -l < {input} > {output}"


def all_annotated_bins(wildcards):
    """Runs again after the checkpoint is done, when the bins can be listed"""
    folder = checkpoints.make_bins.get().output[0]
    bins = glob_wildcards(f"{folder}/{{bin}}.fastq").bin
    return expand("results/annotated/{bin}.txt", bin=sorted(bins))


rule report:
    input:
        all_annotated_bins,
    output:
        "results/report.txt",
    shell:
        "cat {input} | wc -l > {output}"
```

Three parts work together:

- `checkpoint make_bins:` looks like a rule, with the word `checkpoint` instead.
- `rule report` gets its input from a function. The function asks for the checkpoint's result with `checkpoints.make_bins.get()`.
- If the checkpoint hasn't run yet, that call stops the function, and Snakemake notes that this part of the plan can't be known yet. When the checkpoint has finished, Snakemake calls the function again, and it can now list the files.

## What it looks like

The dry run can only see the first step, and says so:

```text
$ snakemake --cores 1 --dry-run --quiet rules
host: localhost
Building DAG of jobs...
Job stats:
job          count
---------  -------
all              1
make_bins        1
report           1
total            3

DAG of jobs will be updated after completion.
[...]
The run involves checkpoint jobs, which will result in alteration of the DAG of jobs (e.g. adding more jobs) after their completion.
```

There are three jobs in the plan, and `annotate_bin` isn't among them. In the real run, the plan grows:

```text
$ snakemake --cores 2 --quiet rules
[...]
Select jobs to execute...
Execute 1 jobs...
DAG of jobs will be updated after completion.
Finished jobid: 2 (Rule: make_bins)
1 of 3 steps (33%) done
Updating checkpoint dependencies.
Select jobs to execute...
Execute 3 jobs...
Finished jobid: 5 (Rule: annotate_bin)
2 of 7 steps (29%) done
[...]
Finished jobid: 0 (Rule: all)
7 of 7 steps (100%) done

$ ls results/annotated
bin_00.txt
bin_01.txt
bin_02.txt
bin_03.txt

$ cat results/report.txt
4
```

Watch the step count go from "1 of 3" to "2 of 7". This was the moment when Snakemake learned there are four bins.

## Costs and alternatives

A checkpoint has some real drawbacks:

- **A dry run can't show the whole plan**, which you can see above. Before the checkpoint has run, you don't see what comes after it.
- **The input function runs many times**, so it should be fast.
- **It adds complexity**, and errors in such functions can be hard to read.

So use one only when you truly need to. Often a simpler way exists. Most tools in this pipeline's binning part get a folder as their input, and handle all the files in it together: dRep takes all bins and returns one folder of genomes, and CheckM2 and GTDB-Tk then process that folder as a whole. No checkpoint is necessary, since **no later job depends on the number of files**. That is why the module `assemble` doesn't need one.

This pipeline uses one checkpoint, in the contig annotation. `contig_annotate__cut_prodigal` splits the predicted proteins of an assembly into chunks of a fixed size, and how many chunks result depends on the assembly. Each chunk then gets its own eggNOG job, which makes the slow annotation run in parallel. @sec-module-contig-annotate explains this in detail.

## Summary

- A checkpoint is a rule after which Snakemake reconsiders the plan.
- An input function asks for its result with `checkpoints.name.get()`, and lists the files with `glob_wildcards`.
- Use a folder as output when later jobs don't depend on the number of files, and a checkpoint only when they do.
