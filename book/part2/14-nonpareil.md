# Nonpareil {#sec-tool-nonpareil}

## What it does

Nonpareil estimates how well your sequencing covered the community. In other words: of all the DNA in the sample, what share did you see at least once? It answers a question you want answered before spending weeks on an assembly: was this enough sequencing, or would more help?

It needs no database or reference, which makes it especially useful for poorly known communities.

## How it works

The idea is simple. If you sequence a community deeply, a new read will very likely overlap with a read you already have. If you sequenced too little, most new reads are about something you haven't seen yet. So the redundancy of the reads tells you about the coverage.

Nonpareil takes a sample of the reads as queries, and for each it checks whether it matches any of the other reads. In `kmer` mode, it does this by comparing k-mers of 24 bases, and this is fast. From this it computes the redundancy at many depths, by sub-sampling, and this gives a curve of coverage against sequencing effort.

The R package `Nonpareil` fits a model to this curve, and it reports these values:

| Value | Meaning |
|-------|---------|
| `C` | The coverage of the data set, from 0 to 1 |
| `LR` | How much sequence you've actually got |
| `LRstar` | How much sequence you'd need to reach 95% coverage |
| `diversity` | Nonpareil diversity (Nd), a measure of the complexity of the community |

Because the diversity is on a scale that doesn't depend on depth, you can use it to compare communities. Rumen samples tend to have high values.

## Input

One FASTQ or FASTA file (`-s`). It uses **one mate only**, because the two mates of a pair aren't independent. It needs an uncompressed file, and it can't read from a pipe. Reads have to be at least as long as the k-mer, and this is why fastp keeps reads of 25 bases or more.

## Output

All files share the prefix from `-b`:

| File | Content |
|------|---------|
| `.npo` | The redundancy curve, which is the main result |
| `.npa` | All pairs of values, in full detail |
| `.npc` | Raw counts per query read |
| `.npl` | The log |

## When to use it

Use it early, on all samples, in any metagenome project. The results help you to decide about further sequencing, and they can explain poor assemblies later. If the coverage is low, say below 60%, you shouldn't expect to recover genomes of more than the most abundant organisms.

## In this pipeline

The rule `read_annotate__nonpareil__run` unpacks the forward reads, and it runs:

```bash
nonpareil -s "${{prefix}}_1.fq" -T kmer -b "$prefix" -f fastq -t {threads} -X {params.X}
```

`read_annotate__nonpareil__aggregate` then runs `workflow/scripts/nonpareil_summary.R`, which reads all `.npo` files with the R package, and it writes `nonpareil.tsv`, with one line per library.

`-X` is the number of query reads, and the default in `params.yaml` is 100, for quick testing. The comment there says so. Fewer query reads make the estimate less precise, so raise this value for an analysis you want to report.

## On real data

@sec-tutorial-read-annotate shows real output of this tool, and how to read it.

## Pitfalls

- **`-X` too low**, as just explained.
- **Too little data.** With low coverage, the model can't be fitted. The values `C` and `LR` are still reported, but `modelR` and `LRstar` are `NA` in the summary, and `diversity` is 0, which doesn't mean a community without diversity. The R package warns with `Median of the curve is zero at 50% of the reads`. With even less data, Nonpareil can leave empty files. Their outputs are marked `touch()` in the rule, so that Snakemake can go on, and such a library is left out of the summary.
- **Too many reads for its memory.** Nonpareil has its own memory setting, `-R`, and on large read files it may use only part of the reads.
- **Disk space.** The uncompressed file takes space until the rule deletes it, and if a job gets killed, it stays there.

## References

Rodriguez-R LM, Konstantinidis KT (2014). Nonpareil: a redundancy-based approach to assess the level of coverage in metagenomic datasets. *Bioinformatics*. <https://doi.org/10.1093/bioinformatics/btt584>

Rodriguez-R LM, Gunturu S, Tiedje JM, Cole JR, Konstantinidis KT (2018). Nonpareil 3: Fast Estimation of Metagenomic Coverage and Sequence Diversity. *mSystems*. <https://doi.org/10.1128/mSystems.00039-18>
