# Targets: `rule all` and `expand()` {#sec-targets}

A real workflow has to produce results for many samples, and nobody wants to type all those file names. This chapter shows
how to ask for everything at once. The example is in `book/examples/snakemake/04_targets/`.

## A rule that only asks for files

If you don't name a target, Snakemake uses the **first rule** in the file. By convention that is a rule called `all` that has
inputs but no output and no command:

```python
SAMPLES = ["sampleA", "sampleB", "sampleC"]


rule all:
    """What a run without any target name produces"""
    input:
        "results/summary.tsv",


rule count_reads:
    input:
        "data/{sample}_R{mate}.fastq.gz",
    output:
        "results/counts/{sample}_R{mate}.txt",
    shell:
        "zcat {input} | wc -l | awk '{{print $1 / 4}}' > {output}"


rule summary:
    """One table with a line per read file"""
    input:
        expand("results/counts/{sample}_R{mate}.txt", sample=SAMPLES, mate=[1, 2]),
    output:
        "results/summary.tsv",
    shell:
        """
        for count in {input}; do
            printf '%s\\t%s\\n' "$(basename "$count" .txt)" "$(cat "$count")"
        done > {output}
        """
```

A rule without output and command runs nothing. It only says "I need these files", and this makes the jobs that produce them
necessary. `rule all` has no wildcards, so Snakemake can work out everything from it.

## `expand()` writes the list for you

`expand()` fills a pattern with all combinations of the values you give it. So this line:

```python
expand("results/counts/{sample}_R{mate}.txt", sample=SAMPLES, mate=[1, 2])
```

produces this list of six files:

```text
results/counts/sampleA_R1.txt
results/counts/sampleA_R2.txt
results/counts/sampleB_R1.txt
results/counts/sampleB_R2.txt
results/counts/sampleC_R1.txt
results/counts/sampleC_R2.txt
```

`SAMPLES` is a normal Python variable, and you can write Python in a Snakefile almost anywhere. @sec-python introduces the
parts you need.

Note that `summary` itself has no wildcard: its output is one fixed file. This is the typical shape of an **aggregation
step**, which collects many results into one. In the command, `{input}` becomes all six file names with spaces between them,
which is what the `for` loop goes through.

Let's run it:

```text
$ snakemake --cores 2 --quiet rules
[...]
Job stats:
job            count
-----------  -------
all                1
count_reads        6
summary            1
total              8
[...]
8 of 8 steps (100%) done

$ cat results/summary.tsv
sampleA_R1	40
sampleA_R2	40
sampleB_R1	60
sampleB_R2	60
sampleC_R1	25
sampleC_R2	25
```

From one target came eight jobs. If you add a sample to the list, only its two count jobs and the summary run again.

## Target rules for parts of a workflow

Nothing forces you to have only one rule like this, and it doesn't have to be first. Here is another one in the same file:

```python
rule counts:
    """A target rule: it runs nothing and only asks for files"""
    input:
        expand("results/counts/{sample}_R1.txt", sample=SAMPLES),
```

Now you can ask for a part of the workflow by the rule's name:

```text
$ snakemake counts --cores 1 --dry-run --forceall --quiet rules
host: localhost
Building DAG of jobs...
Job stats:
job            count
-----------  -------
count_reads        3
counts             1
total              4
[...]
```

This is how the whole pipeline is organised. When you run `bash run_Snakebite-Holoruminant-MetaG.sh assemble__megahit`, then
`assemble__megahit` is exactly such a rule. It lists the assemblies, and Snakemake does what is necessary to produce them.
Each tool has one, each module has one, and `rule all` combines the modules.

Two commands list what is available:

```text
$ snakemake --list-rules
all (What a run without any target name produces)
count_reads
counts (A target rule: it runs nothing and only asks for files)
summary (One table with a line per read file)

$ snakemake --list-target-rules
all (What a run without any target name produces)
counts (A target rule: it runs nothing and only asks for files)
summary (One table with a line per read file)
```

The second list has the rules you can use as a target by name, which are all those without wildcards.

## Using another rule's inputs

To avoid writing the same list twice, a rule can refer to another one with `rules.<name>.input`:

```python
rule qc:
    input:
        rules.qc__filter.input,
        rules.qc__report.input,
```

The pipeline does this constantly: `rule all` in `workflow/Snakefile` is just a list of `rules.preprocess.input`,
`rules.assemble.input` and so on. One thing to watch for is that the referenced rule must already be defined at that point in
the file, which is why the Snakefile includes the modules before `rule all`, and why this one rule isn't at the top.

You may wonder how `rule all` can still be the default target there, since many rules come before it. The answer is that rules
from included files don't count for this: the default is the first rule in the main Snakefile itself, and in the pipeline that is
`rule all`. So running the pipeline without any target means running all of it. A rule can also claim this role with the directive
`default_target: True`, wherever it stands.

## Finding samples from file names

Instead of listing samples, you can get them from the files that exist. `glob_wildcards()` does the reverse of `expand()`: it
takes a pattern, and finds the values:

```python
# Find the samples from the file names instead of listing them
SAMPLES = glob_wildcards("data/{sample}_R1.fastq.gz").sample
print("Found samples:", SAMPLES)
```

```text
$ snakemake --snakefile Snakefile.glob --cores 1 --dry-run --quiet rules
Found samples: ['sampleB', 'sampleA', 'sampleC']
[...]
```

Note the order of the samples, which comes from the file system. This pipeline doesn't work this way for samples, and there
is a good reason: a sample sheet states what you intended to analyse, including settings per sample, and a forgotten or extra
file becomes an error rather than a silent change to your results. The next chapter does it that way.

## Summary

- The first rule is the default target, and `rule all` by convention lists what you want in the end.
- `expand()` builds lists of file names.
- A rule without output is a target rule, and you can ask for it by name.
- This pipeline has such a rule per tool and per module.
