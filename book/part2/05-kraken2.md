# Kraken2 {#sec-tool-kraken2}

## What it does

Kraken2 assigns each read to a taxon, by comparing its k-mers with a database of known genomes. It answers the question of which organisms the reads come from, and it does this very fast. It takes minutes for millions of reads, because it doesn't align anything.

## How it works

The database is built from many genomes. For each k-mer in those genomes, it stores one taxon: the lowest common ancestor (LCA) of all genomes that contain this k-mer. A k-mer that only occurs in *Escherichia coli* points to that species. A k-mer found in all Enterobacteriaceae points to that family.

To classify a read, Kraken2 looks up each of its k-mers. This gives a set of hits, each hitting a node of the taxonomic tree. Kraken2 then finds the path from the root to a leaf in the tree with the most hits, and the read gets the taxon at the end of that path.

To save memory, Kraken2 doesn't store all k-mers, but only minimizers: within each stretch of 35 bases, by default, only one shorter sequence of 31 bases is stored. It also stores them in a compact hash table, which can give a small rate of wrong matches, and this is what makes it possible to hold such a large database in memory.

**Important:** by default, a read is classified with very little evidence. The option `--confidence` sets how many of a read's k-mers must support the taxon, and it defaults to 0. With a value of 0, a single matching k-mer can classify a read. A higher value gives fewer but more reliable assignments.

## Input

FASTQ or FASTA, single or paired, with or without compression, and a database, which is a folder with three files: `hash.k2d`, `opts.k2d` and `taxo.k2d`.

## Output

**The report** (`--report`) is what you usually read. It has one line per taxon, indented by rank, and it's in the form of a tree:

| Column | Content |
|--------|---------|
| 1 | Percentage of reads in this clade |
| 2 | Number of reads in this clade, including those below it |
| 3 | Number of reads assigned directly to this taxon |
| 4 | Rank code: `U` unclassified, `R` root, `D` domain, `K`, `P`, `C`, `O`, `F`, `G`, `S` for kingdom through species |
| 5 | NCBI taxon number |
| 6 | Name, indented |

**The per-read output** goes to the file named by `--output`, or to the standard output without this option. It has one line per read:

| Column | Content |
|--------|---------|
| 1 | `C` classified or `U` unclassified |
| 2 | Name of the read |
| 3 | Taxon number |
| 4 | Length |
| 5 | Which k-mers hit which taxa |

This file is as long as your read file, which is why the pipeline compresses it.

## When to use it

Use it for a quick overview of what's in a sample, especially if a good reference database exists for your habitat, and for finding contamination: human or other unexpected taxa stand out at once.

Keep these limits in mind:

- **It only finds what's in the database.** In rumen samples, many organisms have no close reference. A large share of unclassified reads is normal. It doesn't say that your sample is poor.
- **Percentages of reads aren't abundances of organisms.** Large genomes get more reads than small ones, and Kraken2 doesn't correct for this. Bracken, a separate tool, estimates abundance from the reports. It's not in this pipeline.
- **Species-level calls are often uncertain**, and a tool based on genomes or marker genes, such as sylph or SingleM, is better for that.

## In this pipeline

The rule `read_annotate__kraken2__assign`, which @sec-module-read-annotate explains in detail, runs all samples in one job, so that the database has to be loaded once. It copies the database to `/dev/shm` or to a fast disk first, and it reads it with `--memory-mapping`. This is also why this rule uses the whole node, in the resource set `full_node`.

It uses the reads after fastp and **before** host removal. So the report also tells you how much host DNA there is.

No `--confidence` is set, so the default of 0 applies, and you should keep that in mind when reading low-abundance taxa.

Databases are listed in `features.yaml`. The `standard` database needs about 140 GB of memory, and `refseq500` about 1.4 TB.

## Pitfalls

- **False positives at low abundance.** With `--confidence 0`, you'll see many taxa with a few reads each. Most of them aren't real. Look at the upper part of the report first.
- **Too little memory or disk.** The database has to fit. If it doesn't fit into `/dev/shm`, the job fails on purpose in this pipeline, and it waits for a bigger resource set.
- **Shared nodes.** Files in `/dev/shm` count as memory, so on a shared node this could disturb others. That's why it's a full node here.
- **Comparing databases.** Results from two databases aren't directly comparable, because the share of classified reads depends on what's in them.

## Reference

Wood DE, Lu J, Langmead B (2019). Improved metagenomic analysis with Kraken 2. *Genome Biology*. <https://doi.org/10.1186/s13059-019-1891-0>
