# MetaPhlAn {#sec-tool-metaphlan}

## What it does

MetaPhlAn estimates which organisms are in a sample and how abundant they are. It uses marker genes that are specific to a clade: genes that all members of a group have, and that no other organisms have. A read on such a gene is strong evidence for that group.

MetaPhlAn is one of the most used profilers, particularly for human samples, for which it has the best reference data.

## How it works

Its database holds millions of marker genes. Version 4 includes genomes assembled from metagenomes, and it groups them into species-level genome bins (SGBs). This makes it able to report species that were never cultured.

MetaPhlAn maps the reads against all markers with Bowtie2. For each clade, it counts the coverage of its markers, and it computes the average, ignoring the markers with extreme values. It then normalizes these so that they sum up to 100%.

As the markers are specific, a read that maps to them is nearly always right, so this method has few false positives. But it only sees a small part of the reads: most of them don't fall on any marker, and that's expected.

## Input

FASTQ, with the option `--input_type fastq`, and a Bowtie2 index of the markers (`--bowtie2db`). Paired files are given separated by a comma, and they are treated as single reads: MetaPhlAn doesn't use the pairing.

## Output

| File | Content |
|------|---------|
| `-o` | The profile, as a table |
| `--bowtie2out` | The mapping, which allows running MetaPhlAn again with other settings, without mapping again |

The profile has one line per clade, at all ranks from kingdom to SGB:

| Column | Content |
|--------|---------|
| `clade_name` | The clade, such as `k__Bacteria|p__Bacteroidota|...`. The levels are `k__`, `p__`, `c__`, `o__`, `f__`, `g__`, `s__`, `t__` |
| `NCBI_tax_id` | The taxon numbers of that path |
| `relative_abundance` | Percentage |
| `additional_species` | Other species in this SGB |

`merge_metaphlan_tables.py` joins the profiles of many samples.

## When to use it

Use it for human samples, and in general where the organisms are well represented in the database. Since it reports relative abundances of the known species, it's a common choice for comparing many samples.

Keep the database in mind in other habitats. In rumen samples, for example, its reports can cover only part of the community. The abundances add up to 100% regardless, so they don't show you how much is missing. An option, `--unclassified_estimation`, adds an estimate of the unknown part.

## In this pipeline

The rule `read_annotate__metaphlan__run` maps the clean reads of each library, and `read_annotate__metaphlan__condense` joins the tables into `metaphlan_profiled.tsv`. As HUMAnN uses the profile, this rule also runs if you only ask for HUMAnN.

The database comes from `features.yaml`, and it is the MetaPhlAn database in version 4.

## On real data

This book has no real output of this tool yet. @sec-tutorial-waiting says why, and it will come from a complete run on a cluster.

## Pitfalls

- **A profile that adds up to 100%** can suggest that everything is known, as said above.
- **Database and tool versions must fit.** A version of MetaPhlAn expects a certain database. If they don't match, it stops with an error, or it tries to download one, which can't work in a compute job.
- **Rerunning.** If `--bowtie2out` exists already, MetaPhlAn refuses to run again. Snakemake removes it before a rerun, but keep it in mind for runs by hand.
- **Very low coverage.** A clade needs a minimum share of its markers to be reported. So rare species don't appear, and this gets worse with low sequencing depth.

## Reference

Blanco-Míguez A, et al. (2023). Extending and improving metagenomic taxonomic profiling with uncharacterized species using MetaPhlAn 4. *Nature Biotechnology*. <https://doi.org/10.1038/s41587-023-01688-w>
