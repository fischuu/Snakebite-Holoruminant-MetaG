<a name="toc"></a>
# Table of content 
- The [`reads`](#reads) module
- The [`reference`](#reference) module
- The [`preprocess`](#preprocess) module
- The [`read_annotate`](#read_annotate) module
- The [`assemble`](#assemble) module
- The [`contig_annotate`](#contig_annotate) module
- The [`mag_annotate`](#mag_annotate) module
- The [`quantify`](#quantify) module
- The [`eukaryote`](#eukaryote) module (opt-in)

# Usage

The pipeline can run the entire workflow at once. However, normally it is recommended to run different
modules from the pipeline separated to get better control over the results and also to be able to react
quicker to possible errors.

In the following it is assumed that the pipeline runs on a server that utilizes SLURM and Singularity/Apptainer.
Other setups are also supported, but no default configuration is currently provided. In case you have a
different setup and want to contribute a profile/configuration, please reach out.

For testing and developing, you can add to every command e.g. the option `-np` for a dry-run that prints
the used commands.

Every module has a report, a PDF in `Rreports/`. The rule `all` makes them at the end of a run, and you can
make one on its own by adding `report_` in front of the module name, as in `report_preprocess`. See
[Reports and other output](06-Details.md#reports-and-other-output).

Back to [Table of contents](#toc)

<a name="reads"></a>
## 'reads'-module
Here are some basic steps for the reads are performed.

Usage:

```
bash run_Snakebite-Holoruminant-MetaG.sh reads

# Generate the module report
bash run_Snakebite-Holoruminant-MetaG.sh report_reads
```

For testing, please check first the dry-run with commands printed by running the command like this

```
bash run_Snakebite-Holoruminant-MetaG.sh reads -np
```

For all other modules this works in a similar fashion, just add the `-np`-option for testing and
`report_` to the module to generate a report for the module.

Back to [Table of contents](#toc)

<a name="reference"></a>
## 'reference'-module

The reference host genomes are recompressed in this module.

Usage:

```
bash run_Snakebite-Holoruminant-MetaG.sh reference
```

Back to [Table of contents](#toc)

<a name="preprocess"></a>
## 'preprocess'-module
This module covers the quality control and trimming of the reads

Usage:

```
bash run_Snakebite-Holoruminant-MetaG.sh preprocess

# Generate the module report
bash run_Snakebite-Holoruminant-MetaG.sh report_preprocess
```

Back to [Table of contents](#toc)

<a name="read_annotate"></a>
## 'read_annotate'-module

The command `read_annotate` triggers the analysis of the read-based annotation.

Usage:

```
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate
```

Instead of the entire module, individual tools can also be called by running

```
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__diamond
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__humann
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__kraken2
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__krona
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__metaphlan
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__nonpareil
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__phyloflash
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__singlem
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__sylph
```

The underlying syntax (here and for all other modules) is that an individual tool is always
called by module name, followed by two underscores and the tool name. Please bear in mind that
the pipeline automatically runs the required pre-steps. This syntax hold through-out the entire
pipeline and can be used to run only subparts of the pipeline.

Back to [Table of contents](#toc)

<a name="assemble"></a>
## 'assemble'-module
This module runs all the assembly related tasks, like creating the metagenome and then the
binning and combination of different binners.

Usage (full module):

```
bash run_Snakebite-Holoruminant-MetaG.sh assemble
```

Usage (individual tools):

```
bash run_Snakebite-Holoruminant-MetaG.sh assemble__concoct
bash run_Snakebite-Holoruminant-MetaG.sh assemble__drep
bash run_Snakebite-Holoruminant-MetaG.sh assemble__magscot
bash run_Snakebite-Holoruminant-MetaG.sh assemble__maxbin2
bash run_Snakebite-Holoruminant-MetaG.sh assemble__megahit
bash run_Snakebite-Holoruminant-MetaG.sh assemble__metabat2
bash run_Snakebite-Holoruminant-MetaG.sh assemble__metaspades
```

Back to [Table of contents](#toc)

<a name="contig_annotate"></a>
## 'contig_annotate'-module

This module is running the contig based analysis from beginning to end, meaning it first predicts
genes on the metagenome assembly, annotates the predicted genes with eggnog, aligns the quality
filtered reads to the assembly with bowtie and then quantifies it with coverm.

Usage:

```
bash run_Snakebite-Holoruminant-MetaG.sh contig_annotate
```

Usage for individual tools:

```
bash run_Snakebite-Holoruminant-MetaG.sh contig_annotate__camper
bash run_Snakebite-Holoruminant-MetaG.sh contig_annotate__diamond
bash run_Snakebite-Holoruminant-MetaG.sh contig_annotate__eggnog
bash run_Snakebite-Holoruminant-MetaG.sh contig_annotate__eggnog7
bash run_Snakebite-Holoruminant-MetaG.sh contig_annotate__featurecounts
bash run_Snakebite-Holoruminant-MetaG.sh contig_annotate__hmmer
bash run_Snakebite-Holoruminant-MetaG.sh contig_annotate__prodigal
```

Back to [Table of contents](#toc)

<a name="mag_annotate"></a>
## 'mag_annotate'-module


This module is the MAG annotation workhorse, it aligns the mags against various databases and
generates the annotation for them.

Usage:

```
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate
```

Individual tools can be accessed like:

```
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__bakta
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__camper
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__checkm2
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__dram
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__dram_mag
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__eggnog
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__gtdbtk
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__phylophlan
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__proteinortho
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__quast
```

Back to [Table of contents](#toc)

<a name="quantify"></a>
## 'quantify'-module

After creating the assemblies, this module does the mapping of the reads and generates the
quantification tables for the samples.

Usage:

```
bash run_Snakebite-Holoruminant-MetaG.sh quantify
```

Back to [Table of contents](#toc)

<a name="eukaryote"></a>
## 'eukaryote'-module

This module labels the contigs of every assembly as eukaryotic or prokaryotic with Tiara, 4CAC and REMAG,
and REMAG also bins the eukaryotic contigs. It is meant for samples with a relevant eukaryotic share, such
as soil. The binning in the `assemble` module scores bins with bacterial and archaeal marker genes, so
eukaryotic bins don't come out of it.

The module is not part of a complete pipeline run, so you have to call it explicitly. No databases are needed.

Usage:

```
bash run_Snakebite-Holoruminant-MetaG.sh eukaryote
```

Usage for individual tools:

```
bash run_Snakebite-Holoruminant-MetaG.sh eukaryote__4cac
bash run_Snakebite-Holoruminant-MetaG.sh eukaryote__remag
bash run_Snakebite-Holoruminant-MetaG.sh eukaryote__tiara
```

4CAC reads the assembly graph of metaSPAdes, so it only runs with `assembler: "metaspades"`. With MEGAHIT or
self-provided assemblies, the `eukaryote__4cac` target does nothing and the other two tools still run.

The settings are in the `eukaryote` section of `config/params.yaml`. The output files are described in the
[module details](06-Details.md#eukaryote-module).

For a project folder created before version 0.4.66, first copy these entries from the pipeline's `config/`
folder into the project's own:

- the `eukaryote` section of `params.yaml`
- the `4cac`, `remag` and `tiara` lines of `.docker.yml`
- the `eukaryote__` lines of `escalation.yaml`

Back to [Table of contents](#toc)