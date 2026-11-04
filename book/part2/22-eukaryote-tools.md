# Tiara {#sec-tool-tiara}

## What it does

Tiara sorts sequences of a metagenome into classes, in particular eukaryotic or prokaryotic, with a neural network that uses k-mer frequencies. It also picks out sequences from organelles. So it's the quick first step when you want to find the eukaryotes in an assembly.

## How it works

It classifies each sequence in two stages:

1. The first stage decides between `archaea`, `bacteria`, `prokarya`, `eukarya`, `organelle` and `unknown`.
2. The second looks at the organelles, and it decides between `mitochondrion`, `plastid` and `unknown`.

A class needs a probability above a cutoff for each stage (`--prob_cutoff`). Otherwise it's `unknown`.

## Input

A FASTA file with the contigs (`--input`), which can be compressed. By default, it ignores those shorter than 3000 bases (`--min_len`), since classification on short sequences is less reliable.

## Output

| File | Content |
|------|---------|
| `--output` | The table |
| `log_<name>` | The number of sequences per class. This is the quickest summary |

The table holds these columns:

| Column | Content |
|--------|---------|
| `sequence_id` | The contig |
| `class_fst_stage` | Class from the first stage |
| `class_snd_stage` | Class from the second stage, or `n/a` |
| Further columns | With `--probabilities`, the probabilities per class |

## When to use it

Use it as a fast filter for eukaryotic contigs. It has only modest resource needs.

## In this pipeline

The rule `eukaryote__tiara__run` runs it per assembly, as @sec-module-eukaryote shows. `min_len` is 1000 here, and the comment in `params.yaml` explains that this is the tool's documented lower limit, chosen so that assemblies with short contigs, such as those from soil, don't get thinned out.

## Pitfalls

- **Short contigs.** With `min_len` 1000, the shortest contigs get the least reliable labels.
- **`prokarya` versus `bacteria`.** A contig in `prokarya` is one that's clearly prokaryotic, but not clearly one of the two domains.
- **Eukaryotic genes in bacteria**, and the other way around. Horizontal gene transfer can mislead classification by composition.

## Reference

Karlicki M, Antonowicz S, Karnkowska A (2022). Tiara: deep learning-based classification system for eukaryotic sequences. *Bioinformatics*. <https://doi.org/10.1093/bioinformatics/btab672>

# 4CAC {#sec-tool-4cac}

## What it does

4CAC classifies the contigs of an assembly into four groups: phages, plasmids, prokaryotic chromosomes and eukaryotes. Other tools usually only do one of those distinctions. Its special contribution is that it uses the assembly graph, in addition to the sequences.

## How it works

1. A classifier (XGBoost) gives each contig a score for each class, based on its k-mers.
2. For contigs whose class is clear, the label is kept. Then 4CAC looks at the assembly graph: neighboring contigs often come from one element. So a contig without a clear label can take the class from its neighbors.

The graph is the reason why it has to be an assembly with a graph it can read.

## Input

| Option | Content |
|--------|---------|
| `classify_xgb.py --fasta` | The contigs |
| `classify_4CAC.py --asmdir` | The assembler's folder, with the contigs, the paths and the graph |
| `--assembler` | Which assembler made these, here `metaSPAdes` |
| `--phage`, `--plasmid` | Minimum scores |

## Output

`4CAC_classification.fasta`, whose sequence names hold the classes. A script of this pipeline turns that into a table, see below.

## When to use it

Use it when plasmids and phages matter too, or to back up other classifiers. It needs an assembler's graph, and in this pipeline it only works for metaSPAdes.

## In this pipeline

Two rules run it: `eukaryote__4cac__extract_graph` gets the files from the archive of the working folder of metaSPAdes, and `eukaryote__4cac__run` runs the two steps, plus the translation of names. The result has one line per contig:

| Column | Content |
|--------|---------|
| `contig_id` | The name in this pipeline |
| `node_id` | The name from metaSPAdes |
| `class` | `phage`, `plasmid`, `prokarya`, `eukarya` or `uncertain` |
| Four more | The scores of the first step |

This comes from a third-party image, `metagenlab/4cac:1.0`, with the scripts in `/pkg/4CAC`. `workflow/scripts/fourcac_to_contig_ids.py` translates the names, by repeating the numbering of `contig_ids.py`. So if you ever change one of the two, change the other too.

## Pitfalls

- **MEGAHIT or your own assemblies.** The target does nothing then, as @sec-module-eukaryote explains.
- **Memory.** The resource sets of this rule escalate up to `highmem`, as large graphs can take a lot of it.

## Reference

Pu L, Shamir R (2024). 4CAC: 4-class classifier of metagenome contigs using machine learning and assembly graphs. *Nucleic Acids Research*. <https://doi.org/10.1093/nar/gkae799>

# REMAG {#sec-tool-remag}

## What it does

REMAG recovers genomes of eukaryotes from a metagenome. It does two things that are usually separate: it filters the contigs for eukaryotes, and then it bins them. Most binners and their refinement steps are built for Bacteria and Archaea, so a tool like this fills a real gap.

## How it works

1. **Filter.** A classifier based on HyenaDNA, a deep language model for DNA, gives each contig a probability of being eukaryotic.
2. **Bin.** It learns a representation of the contigs using self-supervised learning, based on their sequences and coverage, and it clusters them into bins.

## Input

| Option | Content |
|--------|---------|
| `--fasta` | The contigs, which can be compressed |
| `--coverage` | A BAM or CRAM file, one option per sample |
| `--output` | The folder |
| `--filter-only` | Stop after the filter |
| `--min-contig-length`, `--min-bin-size` | Limits |

## Output

| File | Content |
|------|---------|
| `<name>.fa_hyenadna_classification.tsv` | The classification |
| `<name>.fa_eukaryotic_filtered.fasta` | The contigs called eukaryotic |
| `bins/` | The bins |
| `bins.csv` | Which contig is in which bin |
| `remag*.log` | Logs. A log file gets replaced by a new one at 10 MB |

The classification table has these columns: `contig_id`, `length`, `prediction`, `eukaryote_prob`, `confidence`, `num_windows`, `resampled`.

## When to use it

Use it for samples with a real share of eukaryotes, such as soil, sediments, or a rumen with fungi and protists. It's a young tool, so expect it to change, and check its bins with care.

It benefits from a GPU, but it also works without one, only more slowly.

## In this pipeline

Two rules run it, as @sec-module-eukaryote shows in detail. `eukaryote__remag__filter` only classifies, and `eukaryote__remag__bin` continues in the same folder.

Two precautions in these rules are worth noting:

- REMAG doesn't stop with an error when its classifier can't be loaded or a batch fails. It keeps the contigs as eukaryotic, and it only writes this to the log. So the rule looks for these messages and fails by itself.
- If the contigs called eukaryotic add up to less than `min_bin_size`, then the rule skips the binning, as REMAG would stop with an error.

## Pitfalls

- **`min_contig_length` must stay the same** between the two steps, or REMAG refuses to resume.
- **Bins aren't in the catalogue.** They don't go through CheckM2, MAGScoT or dRep. Check them with a tool for eukaryotes.
- **Time.** The rule can escalate to `longrun` and `highmem_longrun`, as training takes long without a GPU.

## Reference

Gómez-Pérez D, et al. (2026). REMAG: recovery of eukaryotic genomes from metagenomic data using non-contrastive self-supervised learning. Preprint. <https://doi.org/10.64898/2026.03.05.709928>
