# Wildcards: one rule for many files {#sec-wildcards}

The previous rule could count the reads of a single file. For 100 samples you won't write 100 rules, and this is what
wildcards are for. The example is in `book/examples/snakemake/02_wildcards/`.

## Replacing names with placeholders

Here is the same rule with two placeholders:

```python
rule count_reads:
    input:
        "data/{sample}_R{mate}.fastq.gz",
    output:
        "results/{sample}_R{mate}.count.txt",
    shell:
        "zcat {input} | wc -l | awk '{{print $1 / 4}}' > {output}"
```

`{sample}` and `{mate}` are **wildcards**. The rule now says: to make any file named like
`results/<something>_R<something>.count.txt`, read the file `data/<same something>_R<same something>.fastq.gz`.

## Snakemake can't guess what you want

If you run this as before, it fails:

```text
$ snakemake --cores 1
Assuming unrestricted shared filesystem usage.
host: localhost
Building DAG of jobs...
WorkflowError:
Target rules may not contain wildcards. Please specify concrete files or a rule without wildcards at the command line,
or have a rule without wildcards at the very top of your workflow (e.g. the typical "rule all" which just collects
all results you want to generate in the end).
[exit code 1]
```

Without a target, Snakemake uses the first rule in the file, and it can't fill in the wildcards on its own. This message
even tells you the solution, and we will use both options. The first option is to name the file you want:

```text
$ snakemake --cores 1 results/sampleB_R2.count.txt
[...]
localrule count_reads:
    input: data/sampleB_R2.fastq.gz
    output: results/sampleB_R2.count.txt
    jobid: 0
    reason: Missing output files: results/sampleB_R2.count.txt
    wildcards: sample=sampleB, mate=2
    resources: tmpdir=/tmp
[...]
```

Look at the line `wildcards: sample=sampleB, mate=2`. This is the core of how it works: Snakemake compared the name you
asked for with the rule's output pattern, and worked out the values. It then put them into the input pattern. **Wildcards
always flow from output to input**, which is the opposite of how you may think about the data.

You can ask for several files at once:

```text
$ snakemake results/sampleC_R1.count.txt results/sampleC_R2.count.txt --cores 1 --quiet
[...]
$ ls results
sampleB_R2.count.txt
sampleC_R1.count.txt
sampleC_R2.count.txt
```

Notice that the targets now come first. Options like `--quiet` can take values of their own, and this is what happens if a
target follows one:

```text
$ snakemake --cores 1 --quiet results/sampleC_R1.count.txt 2>&1 | tail -n 1
snakemake: error: argument --quiet/-q: invalid choice: 'results/sampleC_R1.count.txt' (choose from all, host, progress, reason, rules)
```

So put targets directly after `snakemake`. The options `--dag`, `--rulegraph` and `--set-threads` behave in the same way.

## Two errors worth recognising

The output pattern may match, but the input may be missing:

```text
$ snakemake --cores 1 results/sampleZ_R1.count.txt
Assuming unrestricted shared filesystem usage.
host: localhost
Building DAG of jobs...
MissingInputException in rule count_reads in file "/scratch/project_demo/examples/02_wildcards/Snakefile", line 1:
Missing input files for rule count_reads:
    output: results/sampleZ_R1.count.txt
    wildcards: sample=sampleZ, mate=1
    affected files:
        data/sampleZ_R1.fastq.gz
[exit code 1]
```

This says what it could work out and which file it needs. Most of the time, it means a typo in a sample name, a wrong path,
or an earlier rule that should produce the file but is missing.

Or the name you ask for may fit no rule at all:

```text
$ snakemake --cores 1 results/sampleA.count.txt
Assuming unrestricted shared filesystem usage.
host: localhost
Building DAG of jobs...
MissingRuleException:
No rule to produce results/sampleA.count.txt (if you use input functions make sure that they don't raise unexpected exceptions).
[exit code 1]
```

Here `sampleA.count.txt` lacks the `_R<mate>` part, so no output pattern matches. When you see this, compare your file
name character by character with the rule's output.

## How matching really works

By default, a wildcard matches any text of at least one character, including slashes. This has consequences:

- Every wildcard in `input:` must also be in `output:`, since that is the only place its value can come from.
- The same wildcard can appear several times in a pattern, and has to have the same value everywhere.
- A pattern can match in more ways than you meant. If a sample is called `sample_R1`, then `sample_R1_R1.count.txt` can be
  split in more than one way. Snakemake's matching prefers the longest possible match.

The last point can cause confusing errors in bigger workflows. When two wildcards are next to each other or a name can
contain separators, restrict what a wildcard may match with a regular expression:

```python
rule count_reads:
    input:
        "data/{sample}_R{mate}.fastq.gz",
    output:
        "results/{sample}_R{mate}.count.txt",
    wildcard_constraints:
        mate="[12]",
```

The rule then only matches when `mate` is 1 or 2. This pipeline uses the same idea in its hmmsearch rule, where
`marker_set="pfam|tigr"` limits a wildcard to two values (@sec-module-assemble).

## Using wildcard values in the command

Inside `shell:`, you can use the value with `{wildcards.sample}`:

```python
    shell:
        "echo 'Counting {wildcards.sample}, mate {wildcards.mate}' && zcat {input} | wc -l > {output}"
```

## Naming conventions in this pipeline

The pipeline uses three kinds of wildcards everywhere. Knowing them makes its rules much easier to read:

| Wildcard | Meaning | Example |
|----------|---------|---------|
| `{sample_id}` | A biological sample, from `samples.tsv` | `cow01` |
| `{library_id}` | One sequencing library of that sample | `L001` |
| `{assembly_id}` | One assembly, which may combine several libraries | `coasm` |

So a file like `results/preprocess/fastp/cow01.L001_1.fq.gz` is written in a rule as
`FASTP / "{sample_id}.{library_id}_1.fq.gz"`. The `FASTP` part is a path constant, which @sec-python explains.

## Summary

- A wildcard lets one rule make many files.
- Values come from matching the requested file name against the output pattern.
- A rule with wildcards can't be a target by itself, so you have to name a concrete file.
- Put targets directly after `snakemake`.

Naming every file on the command line doesn't scale to 100 samples. Before we solve that, the next chapter connects
several rules with each other.
