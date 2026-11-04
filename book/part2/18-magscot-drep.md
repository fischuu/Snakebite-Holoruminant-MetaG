# MAGScoT {#sec-tool-magscot}

## What it does

MAGScoT takes the bins of several binners, scores them by marker genes, and builds the best possible set of bins out of them. So it refines rather than bins. DAS Tool and MetaWRAP's refinement module are tools of the same kind.

## How it works

**Scoring.** Each bin gets an estimate of completeness and contamination from single-copy marker genes. These are the marker sets of GTDB release 207: 120 for Bacteria and 53 for Archaea. If a bin has most of the markers, it's complete. If it has some markers twice, it's contaminated. These go into one score, with three weights you can set:

| Option | Default |
|--------|---------|
| `-a`, `--score_a` | 1 |
| `-b`, `--score_b` | 0.5 |
| `-c`, `--score_c` | 0.5 |

**Merging.** MAGScoT also makes new candidates: if bins from different binners share many markers, then it builds combined bins from them. `--n_iterations` says how many rounds of this it does, and `--skip_merge_bins` turns it off.

**Selecting.** It then goes down the list: it takes the best bin, removes its contigs from all other bins, computes the scores again, and takes the next. Each contig ends up in at most one bin. It stops when no bin reaches the minimum completeness (`-t`).

## Input

| Option | Content | Columns |
|--------|---------|---------|
| `-i` | Which contig is in which bin | Bin, contig, name of the binner. No header |
| `--hmm` | Marker gene hits | Gene, marker, E-value |

The gene name must be the contig name plus `_` and a number, as Prodigal writes it.

## Output

| File | Content |
|------|---------|
| `<out>.refined.out` | The final bins, with their scores |
| `<out>.refined.contig_to_bin.out` | Which contig is in which final bin |
| `<out>.scores.out` | Scores of all bins of all binners |
| `<out>.gtdb_rel207_bac120.out`, `<out>.gtdb_rel207_ar53.out` | Marker counts of the bins |

The file `scores.out` lets you see which binner did best on your data.

## When to use it

Use it after running several binners, as a step before dereplication. It's light on time and memory.

It only knows about Bacteria and Archaea, since the marker genes are theirs. This also means that eukaryotic bins disappear in this step, as they don't have these markers. See @sec-module-eukaryote.

## In this pipeline

Six rules prepare and run it, as @sec-module-assemble shows. The script comes with the pipeline, in `workflow/scripts/MAGScoT/`, under its GPL-3 licence.

Two settings are worth a look:

- `threshold` is 0.5, so bins that are at least 50% complete can pass. This is the default of the tool.
- `extra` holds `--n_iter=1`, which R's option parser takes as `--n_iterations=1`. So there's one round of merging, while the default is 2. The comment in `params.yaml` says that this value might be a relic of testing.

If MAGScoT finds no viable bin, it fails, and the rule accepts this and continues with empty tables. This means that real errors are hidden too, so check the log.

## On real data

@sec-tutorial-assemble shows real output of this tool, and how to read it.

## Pitfalls

- **Names.** The contig names must match exactly between the files. The pipeline's `bin_NA@contig_…` format takes care of this.
- **Few bins.** On a small test data set, there may be no bins that pass. That isn't an error.
- **Missed markers.** Organisms with reduced genomes, such as CPR bacteria, lack some markers, so they look incomplete.

## Reference

Rühlemann MC, Wacker EM, Ellinghaus D, Franke A (2022). MAGScoT: a fast, lightweight and accurate bin-refinement tool. *Bioinformatics*. <https://doi.org/10.1093/bioinformatics/btac694>

# dRep {#sec-tool-drep}

## What it does

dRep reduces a set of genomes to one representative per species, or per another chosen level of similarity. Several assemblies usually recover the same organism again and again. If you were to map reads to all of these copies, the reads would spread randomly among them, and this would ruin your quantification. So a catalogue should hold only one of them, and this is called dereplication.

## How it works

Comparing all genomes with each other exactly would take too long, so dRep does it in two steps.

1. **Filter.** Genomes that fail the length, completeness or contamination limits are removed. It uses CheckM for the estimates, unless you provide values through `--genomeInfo`.
2. **Primary clustering.** A very quick method (Mash) groups the genomes at a low threshold, by default 90% (`-pa`).
3. **Secondary clustering.** Inside each group, a more accurate method compares the genomes (by default fastANI) and groups them at the final threshold, by default 95% (`-sa`). They also need to align over a minimum share of their length, set by `-nc`.
4. **Choosing the winner.** For each final cluster, the genome with the best score is kept. The score combines completeness, contamination, N50 and size.

## Input

Genomes in FASTA format, with one file per genome (`-g`).

## Output

All of these are in the working directory, which is the first argument:

| Path | Content |
|------|---------|
| `dereplicated_genomes/` | The chosen genomes |
| `data_tables/Widb.csv` | The winners with their scores |
| `data_tables/Cdb.csv` | Which genome is in which cluster |
| `data_tables/Mdb.csv`, `Ndb.csv` | All pairwise comparisons of both steps |
| `data_tables/genomeInfo.csv` | Quality of all genomes |
| `figures/` | Plots of the clusters and the scores |
| `log/` | Logs |

## When to use it

Use it each time you combine genomes from several assemblies. The threshold depends on your question: 95% for one genome per species, which is the usual choice, and 98% or 99% for strains. Be aware that a too high threshold brings back the problem of reads spreading between very similar genomes.

## In this pipeline

The rule `assemble__drep__run`, explained in @sec-module-assemble, reads the single bins made by `assemble__drep__split_bins`. It uses these options:

| Option in dRep | Key in `params.yaml` | Value |
|-----------|-----|-----|
| `-comp` | `completeness` | 50 |
| `-con` | `contamination` | 50 |
| `-pa` | `P_ani` | 0.9 |
| `-sa` | `S_ani` | 0.95 |
| `-nc` | `nc` | 0.1 |

Note `-con 50`. dRep's own default is 25, and a genome with up to 50% contamination can get through this filter. The limit is permissive on purpose, and quality filtering is left to you, based on CheckM2, in @sec-tool-checkm2.

The container `hrp_assemble` holds CheckM with its reference data, so dRep can run it without a separate database.

## On real data

@sec-tutorial-assemble shows real output of this tool, and how to read it.

## Pitfalls

- **A single genome.** dRep can't cluster one genome: its run ends with `ValueError: The number of observations cannot be determined on an empty distance matrix`. A real project has more bins than that, but a small test can run into it, as @sec-tutorial shows.
- **CheckM needs a lot of memory.** Its step with `pplacer` needs tens of GB. If it fails, dRep prints `!!! checkM failed !!!`, but it **still exits with 0** and leaves no genomes. So the rule checks for this and stops with a clear message.
- **Hard to resume.** dRep won't start in a folder with old results, and the rule removes them first.
- **The time of CheckM.** Most of the run time may be in CheckM, and not the comparison. Giving it results through `--genomeInfo` avoids this. You could add that through `extra`.
- **The name of the winner.** The file names are kept, so you can see which assembly each winner came from.

## Reference

Olm MR, Brown CT, Brooks B, Banfield JF (2017). dRep: a tool for fast and accurate genomic comparisons that enables improved genome recovery from metagenomes through de-replication. *The ISME Journal*. <https://doi.org/10.1038/ismej.2017.126>
