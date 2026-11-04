# Structuring a large workflow {#sec-structure}

A Snakefile with 170 rules would be unreadable. So you split a workflow into files, with a folder structure that shows how its parts relate. This
chapter uses the same structure as the real pipeline, in small. The example is in `book/examples/snakemake/10_structure/`.

## The layout

```text
$ tree workflow config
workflow
├── Snakefile
└── rules
    ├── folders.smk
    ├── qc
    │   ├── __main__.smk
    │   └── filter.smk
    └── stats
        ├── __main__.smk
        └── count.smk
config
└── config.yaml

5 directories, 7 files
```

Snakemake looks for `Snakefile` and for `workflow/Snakefile`, so you don't have to name it on the command line. The ending `.smk` is a convention for files with
rules. The real pipeline has the same structure, with a folder per module under `workflow/rules/`:

```
workflow/rules/
    folders.smk           the paths of all results
    helpers/              rules that several modules use
    reads/                one folder per module
    reference/
    preprocess/
    read_annotate/
    assemble/
    quantify/
    mag_annotate/
    contig_annotate/
    eukaryote/
    report/
```

## `include:` puts files together

`include:` reads another file as if its text stood at that place. So the main Snakefile stays short:

```python
configfile: "config/config.yaml"

SAMPLES = config["samples"]


include: "rules/folders.smk"
include: "rules/qc/__main__.smk"
include: "rules/stats/__main__.smk"


rule all:
    input:
        rules.qc.input,
        rules.stats.input,
```

Three things to note here:

- A path in `include:` is relative to the file with the `include:` line. That's different from input and output files, whose paths are relative to the folder where you start Snakemake.
- The order matters for plain Python: `SAMPLES` has to be defined before an included file uses it, and `rules.qc` must be defined before `rule all` refers to it. The order of rules doesn't matter otherwise, since Snakemake connects them through file names.
- All included files share one namespace. A variable or function defined in one is visible in all the others, and two functions with the same name silently overwrite each other. That has happened in this pipeline, which is why helper names are specific.

## A module is a folder with a `__main__.smk`

In this pipeline, each module's folder has a file `__main__.smk`, which includes the tool files and defines a target rule named after the module:

```python
include: "filter.smk"


rule qc:
    """Run the whole qc module"""
    input:
        expand(QC / "{sample}.fastq.gz", sample=SAMPLES),
```

and each tool has a file with its rules:

```python
rule qc__filter:
    input:
        "data/{sample}_R1.fastq.gz",
    output:
        QC / "{sample}.fastq.gz",
    shell:
        """
        zcat {input} | paste - - - - | awk -F '\\t' 'length($2) >= 50' | tr '\\t' '\\n' | gzip > {output}
        """
```

The word "module" here means a folder of rules by this pipeline's own convention. Snakemake also has a feature called `module`, which imports a whole foreign workflow, and this pipeline doesn't use it.

## Rule names say where a rule lives

The rule names follow a scheme: **module, two underscores, tool, two underscores, step**. In the real pipeline, `assemble__magscot__hmmsearch` is the step `hmmsearch` of the tool `magscot` in the module `assemble`.

This pays off when you run things:

```text
$ snakemake --list-rules
all
qc (Run the whole qc module)
qc__filter
stats (Run the whole stats module)
stats__count

$ snakemake qc --cores 2 --quiet rules
[...]
Job stats:
job           count
----------  -------
qc                1
qc__filter        2
total             3
[...]

$ snakemake stats --cores 2 --quiet rules
[...]
Job stats:
job             count
------------  -------
stats               1
stats__count        2
total               3
[...]

$ snakemake --cores 2 --quiet rules
[...]
Nothing to be done (all requested files are present and up to date).
```

The same target-rule idea exists on three levels in the real pipeline:

| Level | Example target | Runs |
|-------|----------------|------|
| Whole pipeline | `all` | Everything except opt-in modules |
| Module | `assemble` | All tools of the module |
| Tool | `assemble__megahit` | One tool and everything it needs |

## Paths in one place {#sec-path-constants}

The file `folders.smk` defines all results folders as constants:

```python
QC = Path("results/qc")
STATS = Path("results/stats")
```

Rules then write `QC / "{sample}.fastq.gz"`. In the pipeline, this file also defines the paths that several rules share, such as the following. Each is then written exactly once, so rules can't drift apart:

```python
# Contigs of one assembly: a pipeline assembler writes them here, self-provided ones are expected here
CONTIGS = ASSEMBLE / config["assembler"] / "{assembly_id}.fa.gz"

MAG_GENOMES = DREP / "dereplicated_genomes"
MAG_CATALOGUE = DREP / "dereplicated_genomes.fa.gz"
```

Whichever assembler you choose, downstream rules simply use `CONTIGS`. The constant `LIBRARY = "{sample_id}.{library_id}"` makes the common part of per-library paths shorter:

```python
MAG_CRAM = MAG_MAPPING / f"{LIBRARY}.cram"
```

That is an f-string whose value contains wildcards, which Snakemake fills in later.

## Where to run from: the project folder

One decision shapes how you use this pipeline: **the code and the data live in separate folders**. The pipeline's code sits once in a folder such as `~/git/Snakebite-Holoruminant-MetaG`, and each project has its own folder with its config, reads and results. You start Snakemake in the project folder, and point it to the code:

```bash
cd /scratch/project_2009831/my_project
snakemake -s /users/fischerd/git/Snakebite-Holoruminant-MetaG/workflow/Snakefile --configfile config/config.yaml ...
```

Relative paths in rules like `results/...` and `config/...` therefore refer to the project. The run script hides this detail (@sec-pipeline-patterns). Rule files are found through the Snakefile's location, while scripts are found through the setting `pipeline_folder` in `config.yaml`, which is what `SCRIPT_FOLDER` is built from.

## Summary

- `include:` splits a workflow into files, which all share one namespace.
- In this pipeline, each module is a folder with a `__main__.smk` and one file per tool.
- Rule names follow `module__tool__step`, and target rules exist per tool and per module.
- `folders.smk` keeps each path in one place.
- Code and project are separate folders.
