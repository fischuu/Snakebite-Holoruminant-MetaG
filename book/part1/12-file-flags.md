# Special kinds of output files {#sec-file-flags}

By default, Snakemake treats an output as a normal file that you want to keep. A real pipeline also has temporary files, outputs that
are whole folders and steps that produce no file at all. **Flags** tell Snakemake about these. The example is in
`book/examples/snakemake/08_file_flags/`.

## The example

```python
rule all:
    input:
        "results/final.txt",
        "results/bins",
        "results/checkpoint.done",


rule unpack_reads:
    """An intermediate file: Snakemake deletes it when nothing needs it any more"""
    input:
        "data/sampleA_R1.fastq.gz",
    output:
        temp("results/sampleA.fastq"),
    shell:
        "zcat {input} > {output}"


rule final_result:
    """A protected file: it becomes read-only, so it cannot be deleted by accident"""
    input:
        "results/sampleA.fastq",
    output:
        protected("results/final.txt"),
    shell:
        "wc -l {input} > {output}"


rule make_bins:
    """A tool that writes an unknown number of files into one folder"""
    input:
        "data/sampleB_R1.fastq.gz",
    output:
        directory("results/bins"),
    shell:
        """
        mkdir -p {output}
        zcat {input} | split -l 100 - {output}/bin_
        """


rule mark_done:
    """A tool without a useful output file of its own: touch() creates an empty one on success"""
    input:
        "results/bins",
    output:
        touch("results/checkpoint.done"),
    shell:
        "ls {input} | wc -l"
```

Running it shows what Snakemake does with these flags (shortened):

```text
$ snakemake --cores 1
[...]
localrule mark_done:
    input: results/bins
    output: results/checkpoint.done
    jobid: 4
    reason: Missing output files: results/checkpoint.done; Input files updated by another job: results/bins
    resources: tmpdir=/tmp
Touching output file results/checkpoint.done.
[...]
localrule final_result:
    input: results/sampleA.fastq
    output: results/final.txt
    jobid: 1
    reason: Missing output files: results/final.txt; Input files updated by another job: results/sampleA.fastq
    resources: tmpdir=/tmp
Write-protecting output file results/final.txt.
[...]
4 of 5 steps (80%) done
Removing temporary output results/sampleA.fastq.
[...]

$ ls -l results | cut -c1-11,25-
total 8
drwxr-xr-x 096 Nov  3 16:56 bins
-rw-r--r--   0 Nov  3 16:56 checkpoint.done
-r--r--r--  26 Nov  3 16:56 final.txt

$ ls results/bins
bin_aa
bin_ab
bin_ac
```

Let us go through them.

## `temp()`: delete when no longer needed

A `temp()` file is removed as soon as all jobs that need it have finished. In the output above it says "Removing temporary output
results/sampleA.fastq". This keeps intermediate files from filling your disk, and in metagenomics they can reach terabytes.

The pipeline uses it for intermediate alignments and reads: the CRAM files of each host mapping and the reads left after each host
are temporary, and only the final decontaminated reads stay.

Here is a behaviour you need to know about: if a temporary file is gone, Snakemake doesn't rerun its job for that reason alone, as long
as the results that depend on it are current. Only when a later step needs it again does Snakemake make the temporary file again. So this
can happen: you add a new rule that reads a temporary file, or you force a rerun of one step. Snakemake then quietly reruns a long chain of
earlier jobs to recreate it, which is one more reason to do a dry run first.

For debugging, `--notemp` keeps all temporary files.

## `directory()`: the output is a folder

Some tools write an unknown number of files into a folder. You can't list those in advance, so the folder is the output, marked with
`directory()`. The binners in this pipeline work this way, as does dRep with its `dereplicated_genomes` folder:

```python
    output:
        directory(CONCOCT / "{assembly_id}"),
```

There are some rules for this:

- Your rule has to create the folder itself, unlike the parent folders of normal outputs.
- Other rules can use the folder as an input, as `mark_done` does here. They can't ask for a single file inside it by name, because no
  rule is known to produce that file.
- When a job fails or needs to rerun, Snakemake deletes the whole folder first.
- A folder's date changes when files are added or removed inside it. This can cause unexpected reruns if a tool writes there later.

If the number of files decides which jobs come next, a folder isn't enough, and you need a checkpoint (@sec-checkpoints).

## `touch()`: a marker file for a step with no file output

Some steps have no output file you could name, or their outputs are too many and too unpredictable. `touch()` makes Snakemake create an
empty file when the command succeeds, and later rules can depend on it.

The pipeline uses this for bowtie2 indexes. `bowtie2-build` writes several files with fixed endings next to a prefix. Instead of listing
them all, the rule's output is a marker file with the name of the prefix:

```python
    output:
        index=touch(MAG_INDEX / "dereplicated_genomes"),
    shell:
        "bowtie2-build --threads {threads} {input} {output.index}"
```

Nonpareil uses it for another reason: on samples with too little data it doesn't produce its files, and an empty file then means "no result"
without making the whole workflow fail.

## `protected()`: guard against accidents

A `protected()` file becomes read-only after the job. In the listing above, `final.txt` has the permissions `-r--r--r--`. Snakemake refuses
to overwrite it, so a mistaken rerun can't destroy a result that took three weeks to compute. To rerun it you first have to delete it by
hand. This pipeline doesn't currently use this flag, but it is a good idea for your own expensive results.

## `ancient()`: don't rerun because of the date

`ancient()` goes on an input, and tells Snakemake to ignore that file's date. This is for reference files or databases, where touching the
file shouldn't invalidate all your results:

```python
    input:
        reads="results/{sample}.fq.gz",
        database=ancient("resources/databases/kraken2"),
```

## `pipe()`: a stream between two jobs

`pipe()` connects two jobs through a stream instead of a file. Both have to run at the same time on the same machine, so it is rarely useful on
a cluster. This pipeline doesn't use it, and it pipes inside one rule's command instead.

## `multiext()`: one prefix with several endings

Tools often produce several files with a common prefix. `multiext()` is a short form for listing them:

```python
    output:
        multiext("results/index", ".1.bt2", ".2.bt2", ".3.bt2", ".4.bt2"),
```

## Summary

| Flag | Goes on | Effect |
|------|---------|--------|
| `temp()` | Output | Deleted when nothing needs it any more |
| `directory()` | Output | The output is a folder |
| `touch()` | Output | An empty file is created on success |
| `protected()` | Output | Becomes read-only |
| `ancient()` | Input | Its date doesn't trigger reruns |
| `pipe()` | Output | A stream between two jobs |
| `multiext()` | Input, output | Several files with one prefix |
