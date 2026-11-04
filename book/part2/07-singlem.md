# SingleM {#sec-tool-singlem}

## What it does

SingleM profiles a community with marker genes that nearly all Bacteria and Archaea carry once. It tells you which organisms are present and how much of each. It can also estimate which share of a sample is microbial at all. Because it looks at conserved genes, it can see organisms that have no genome in any database, at least at the level of a higher rank.

## How it works

SingleM looks for a set of single-copy marker genes in the reads. In these genes, it looks at a fixed short window of 60 bases. Reads that cover the window are compared with a reference set, and each window sequence gets a taxonomy.

The idea is that a window in a conserved gene is nearly unique to each species, and comparing all the reads with such windows is much cheaper than comparing them with whole genomes. Because the genes occur once per genome, the number of reads on them directly reflects the number of cells, and it doesn't depend on the size of the genome. This is a real advantage over counting reads on genomes.

The results of all markers are then combined into one profile, in the step called `condense`.

**`singlem microbial_fraction`** compares two numbers: how many bases should come from Bacteria and Archaea according to the profile and their known genome sizes, and how many bases there are in total. The ratio estimates the share of microbial DNA. In a host-associated sample, this is often the first thing you want to know.

## Input

| Command | Input |
|---------|-------|
| `singlem pipe` | FASTQ (`--forward`, `--reverse`) and a metapackage |
| `singlem condense` | Archive tables from `pipe` |
| `singlem microbial_fraction` | FASTQ and a profile from `pipe` |

The metapackage is SingleM's database. Here it's the one for GTDB R220.

## Output

| File | Content |
|------|---------|
| `--taxonomic-profile` | The profile: sample, coverage and taxonomy per line. This is usually what you read |
| `--otu-table` | Window sequences per marker, with counts and taxonomy |
| `--archive-otu-table` | The same in JSON, for combining later |
| `microbial_fraction` output | The share of microbial reads per sample, with its details |

## When to use it

Use it when you want a profile that doesn't depend on a reference genome for each species, and when you want to know how much of a sample is microbial. It's fast enough for many samples and its memory use is moderate.

It doesn't look at eukaryotes or viruses. It says nothing about function. And an organism without a close relative in GTDB is reported only at a higher rank, such as order or family, which is what you'd want.

## In this pipeline

| Rule | Runs |
|------|------|
| `read_annotate__singlem__pipe` | `singlem pipe` per library |
| `read_annotate__singlem__condense` | `singlem condense` over all libraries |
| `read_annotate__singlem__microbial_fraction` | `singlem microbial_fraction` per library |
| `read_annotate__singlem__aggregate_microbial_fraction` | One table of all libraries |

As the comment in the rule says, SingleM's documentation recommends using raw reads, because it doesn't need trimming. The pipeline gives it the clean reads, so that all profilers see the same data. This also means that host reads are gone before the microbial fraction is computed. **So in this pipeline, this share refers to the reads after host removal, and it doesn't tell you how much of the raw sample was host.** For that, look at the mapping to the host genomes in @sec-module-preprocess.

## Pitfalls

- **Temporary space.** `singlem pipe` can write a lot to `$TMPDIR`, which is why the rule writes the free space there to its log.
- **Differences in coverage.** The coverage in the profile isn't a percentage of reads. It's the estimated average coverage of each organism's genome. Convert it to relative abundance if you need that.
- **Low depth.** With little sequencing, rare organisms aren't seen. This happens with any method.

## Reference

Woodcroft BJ, et al. (2025). Comprehensive taxonomic identification of microbial species in metagenomic data using SingleM and Sandpiper. *Nature Biotechnology*. <https://doi.org/10.1038/s41587-025-02738-1>
