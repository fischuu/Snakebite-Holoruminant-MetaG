# Why a workflow system? {#sec-why-snakemake}

A metagenomics analysis isn't one program. In this pipeline, a read file passes through trimming, host removal,
assembly, three binners, bin refinement, dereplication, a dozen annotation tools and quantification. That is about 170
different steps, and most run once per sample or once per assembly, so one project easily means thousands of jobs.

This chapter explains the problem a workflow system solves, and how Snakemake thinks about it. The next chapters then
build up the language rule by rule.

## The script that grows

Most people start with a shell script, and for two samples it works well:

```bash
fastp -i sampleA_R1.fq.gz -I sampleA_R2.fq.gz -o trimmed/sampleA_R1.fq.gz -O trimmed/sampleA_R2.fq.gz
bowtie2 -x host -1 trimmed/sampleA_R1.fq.gz -2 trimmed/sampleA_R2.fq.gz > mapped/sampleA.sam
fastp -i sampleB_R1.fq.gz -I sampleB_R2.fq.gz -o trimmed/sampleB_R1.fq.gz -O trimmed/sampleB_R2.fq.gz
bowtie2 -x host -1 trimmed/sampleB_R1.fq.gz -2 trimmed/sampleB_R2.fq.gz > mapped/sampleB.sam
```

Then the project grows, and each of these questions costs you time:

- **A job failed halfway. What still has to run?** A plain script starts over from the first line, or you comment out
  the lines that worked and hope you got it right.
- **You got three new samples. What now?** Only the new work should run, and every summary table has to be rebuilt.
- **You changed a setting in the trimming step. What is out of date?** Everything that depends on the trimmed reads, and
  nothing else. You have to remember what that is.
- **How do you run 500 jobs at once?** You write submission scripts, and handle dependencies between jobs yourself.
- **Six months later, how exactly was this result made?** The script may have changed since then, and you may have run
  parts of it by hand.

A workflow system answers all of these, and it does so by changing how you describe the work.

## Describe the result, not the steps

A script lists actions in order: do this, then that. Snakemake turns this around. You write **rules**, and each rule says
how to make one kind of file from other files. Then you ask for a result, and Snakemake works backwards.

Imagine you ask for `results/summary.tsv`. Snakemake reasons like this:

1. Which rule can produce `results/summary.tsv`? The rule `summary`, and it needs `results/counts/sampleA.txt`.
2. Does that file exist and is it current? No. Which rule produces it? The rule `count_reads`, and it needs
   `data/sampleA_R1.fastq.gz`.
3. That file exists. So the plan is: run `count_reads`, then `summary`.

This plan is called the **DAG**, a directed acyclic graph: boxes for the jobs and arrows for "this needs that". "Acyclic"
means that no job can depend on its own result. From the DAG, the questions from above answer themselves:

- **What still has to run?** Whatever is missing or out of date. Everything else is left alone.
- **New samples?** Add them to the list, and only their jobs are new.
- **A changed setting?** Snakemake notices the change and reruns that job and everything downstream.
- **500 jobs at once?** Jobs without an arrow between them can run in parallel. Snakemake submits them for you, and respects
  the order.

You will come back to this mental model often: **Snakemake is driven by the output files you ask for, not by the rules in
your file.** A rule that nothing asks for never runs.

## A few words of vocabulary

| Word | Meaning |
|------|---------|
| Snakefile | The file with the rules. Snakemake looks for `Snakefile` or `workflow/Snakefile` |
| Rule | A recipe: from this input, make this output, with this command |
| Job | One concrete run of a rule, for example `count_reads` for sampleA |
| Target | A file or rule you ask for |
| Wildcard | A placeholder in a file name, such as `{sample}`, that lets one rule serve many jobs |
| DAG | The plan: all jobs needed and their order |

## Which Snakemake, and how to get it

This book uses **Snakemake 9.11.6**, the version that the pipeline's run script loads on Puhti. Newer versions work
similarly, but command-line options do change between major versions, and a lot of what you find online was written for
Snakemake 7 or 8. If a command from a web page fails, check the version it was written for.

On a cluster, you usually load Snakemake as a module:

```bash
module load snakemake/9.11.6
snakemake --version
```

Elsewhere, you can install it with conda. The second package is the plugin for submitting jobs to SLURM:

```bash
conda create -n snakemake -c conda-forge -c bioconda snakemake=9.11.6 snakemake-executor-plugin-slurm
conda activate snakemake
```

Neither was run for this book, because the examples use a test cluster with its own installation. @sec-running-the-examples
describes it.

## Running the examples of this book {#sec-running-the-examples}

The chapters about Snakemake use small example workflows, which are all in `book/examples/snakemake/`. Each folder has the
Snakefile and a `commands.sh` with the commands that the chapter shows. They work on six tiny FASTQ files for three samples,
so every example finishes in seconds, and they need no bioinformatics tools. Only standard Linux commands are used.

To make sure the output in this book is real and stays real, the examples run on a **mini cluster**: a container with Debian
Linux, a real SLURM installation with accounting, and Snakemake 9.11.6. With Docker installed, this command builds it and runs
all examples:

```bash
bash book/examples/run_all.sh
```

This stores what each command printed in `book/examples/transcripts/`, and that is the output quoted in the chapters. It also
works as a test: a command that behaves differently than expected makes the run report a problem. The output in the book is
sometimes shortened, which is marked with `[...]`.

You can also use any other Linux system with Snakemake. Copy the folder of an example and the `data` folder together, and run
the commands from `commands.sh`. The examples in the SLURM chapters need `sbatch` and an account, so you would have to adjust
`slurm_account` in their profile.

## What's next

The next chapter writes the first rule, and then each chapter adds one idea. By the end of this part, you will have seen every
Snakemake feature this pipeline uses, and @sec-pipeline-patterns shows how they come together in it.
