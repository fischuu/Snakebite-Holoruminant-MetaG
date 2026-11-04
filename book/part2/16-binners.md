# Binning: the idea {#sec-tool-binning-idea}

After assembly, you have contigs from many organisms, all mixed. Binning sorts them into groups, one per organism, without knowing in advance which organisms there are. It relies on two signals.

**Composition.** Each genome has a typical pattern of short words. The frequency of the four-letter words (tetranucleotides) is rather stable along a genome, and it differs between genomes. This works on contigs of a few kilobases, but it's weak on shorter ones. It also can't separate close relatives well.

**Abundance.** All contigs of a genome come from the same cells, so they should have about the same coverage in a sample. An organism that's abundant in one sample and rare in another shows this pattern on all of its contigs. With many samples, this signal is very strong, as two organisms rarely follow exactly the same pattern.

This is why **the number of samples mapped to an assembly matters so much**. With one sample, you have one coverage value per contig, and organisms with the same abundance can't be told apart. With a co-assembly of several samples, you have many values.

## What can go wrong

- **Contamination:** a bin holds contigs of different organisms.
- **Fragmentation:** one genome ends up in several bins.
- **Missing parts:** mobile elements and islands often have an unusual composition and coverage, so they stay out of the bin they belong to. Even a very good MAG usually lacks them.
- **Unbinned contigs:** many contigs, particularly short ones, aren't in any bin.

Each binner makes different mistakes. That's the reason the pipeline runs three, and uses MAGScoT to combine the results.

# CONCOCT {#sec-tool-concoct}

## What it does

CONCOCT clusters contigs by composition and coverage, using a statistical model. It's the first of the three binners of this pipeline.

## How it works

It first cuts long contigs into pieces of 10 kb. In this way, a long contig gets more weight, and pieces of one contig can even be compared with each other.

For each piece, it computes the k-mer frequencies and the coverage in each sample. It reduces this to a few dimensions with a principal component analysis. Then it fits a Gaussian mixture model, with an upper limit of clusters. By default, this limit is 400.

Finally, each contig goes to the cluster that got most of its pieces.

## Input

| Tool | Input |
|------|-------|
| `cut_up_fasta.py` | The contigs |
| `concoct_coverage_table.py` | The pieces as a BED file, and sorted, indexed BAM files |
| `concoct` | The pieces (`--composition_file`) and the coverage table (`--coverage_file`) |
| `merge_cutup_clustering.py` | The clustering of the pieces |
| `extract_fasta_bins.py` | The contigs and the merged clustering |

## Output

| File | Content |
|------|---------|
| `clustering_gt1000.csv` | Which cluster each piece went to, for contigs of at least 1000 bases |
| `clustering_merged.csv` | The same for whole contigs |
| `<n>.fa` | One FASTA file per bin |

## When to use it

Use it as one voice among several. It tends to work best with many samples, and it needs them more than others do. On its own, it can split genomes into several parts, and that's another reason for following it with a refinement step.

## In this pipeline

The rule `assemble__concoct__run` follows the steps of the manual, as @sec-module-assemble describes, and it keeps only the bins. It's the only binner with its own container, `hrp_concoct`.

The rule uses the default settings of CONCOCT, and it doesn't filter bins by size. Small bins are filtered out later on, by MAGScoT.

## Pitfalls

- **Few samples.** With a single sample, the coverage signal is nearly useless.
- **Memory.** The size of the matrix grows with the number of contigs and samples.
- **Many small bins.** That's expected, and it's no reason for concern, as long as a refinement step follows.

## Reference

Alneberg J, et al. (2014). Binning metagenomic contigs by coverage and composition. *Nature Methods*. <https://doi.org/10.1038/nmeth.3103>

# MaxBin2 {#sec-tool-maxbin2}

## What it does

MaxBin2 assigns contigs to bins with an iterative statistical method. Unlike the others, it first estimates how many genomes there are by using marker genes.

## How it works

1. It looks for 107 single-copy marker genes on the contigs, using FragGeneScan and HMMER. Their counts tell it about how many genomes to expect, and contigs with these genes become the starting points.
2. It runs an expectation-maximization algorithm: from the current guess, it computes for each contig how likely it is to belong to each bin, by tetranucleotide frequencies and coverage. Then it updates the bins, and it repeats this.

## Input

| Option | Content |
|--------|---------|
| `-contig` | The contigs |
| `-abund` | A table with contig name and abundance. For several samples, use `-abund2`, `-abund3`, and so on, or `-abund_list` |
| `-out` | The prefix of the output |
| `-min_contig_length` | Ignore shorter contigs. The default is 1000 |

## Output

| File | Content |
|------|---------|
| `<out>.001.fasta` and so on | The bins |
| `<out>.summary` | Completeness and size of each bin |
| `<out>.noclass` | Contigs that didn't fit any bin |
| `<out>.tooshort` | Contigs that were too short |
| `<out>.log` | The log |

## When to use it

Use it as one voice among several, particularly if you have few samples, since it's less dependent on many of them. Its choice of the number of bins is sound, but it finds only prokaryotes, because of the marker genes.

## In this pipeline

The rule `assemble__maxbin2__run`, which @sec-module-assemble shows in detail, gives it a single abundance file, even with several libraries. The abundance comes from `samtools coverage`, by adding up over all libraries:

```bash
samtools coverage {input.alignments} | sed '/^#/d' | cut -f 1,5 > {output}/maxbin2.coverage
```

There are two things to note here. First, column 5 is the number of covered bases, while MaxBin2 asks for an abundance, such as the mean depth, which is column 7. So a longer contig gets a higher value. And second, as all libraries are summed up, MaxBin2 doesn't get the differences between samples, which is its strongest signal.

The rest of the rule renames the bins to `.fa` and compresses them. Other files of MaxBin2 are removed.

## Pitfalls

- **Few marker genes.** With a small assembly, it may find too few marker genes to start, and it then produces no bins. On small test data, this is what to expect.
- **Long run time.** On large assemblies, MaxBin2 can be the slowest of the three.

## Reference

Wu YW, Simmons BA, Singer SW (2016). MaxBin 2.0: an automated binning algorithm to recover genomes from multiple metagenomic datasets. *Bioinformatics*. <https://doi.org/10.1093/bioinformatics/btv638>

# MetaBAT2 {#sec-tool-metabat2}

## What it does

MetaBAT2 bins contigs by tetranucleotide frequencies and abundance, using a graph. It's fast, it needs few settings, and it's one of the most widely used binners.

## How it works

For every pair of contigs, it computes a score of how alike they are, in composition and in abundance. It then treats the contigs as nodes of a graph, with these scores on the edges, and it partitions this graph into groups. Contigs that aren't placed at first are added later, by looking at their neighbors. It adapts the weights automatically, which is why it hardly needs any tuning.

## Input

| Tool | Input |
|------|-------|
| `jgi_summarize_bam_contig_depths` | Sorted BAM files |
| `metabat2` | The contigs (`-i`) and the depth table (`-a`) |

## Output

| File | Content |
|------|---------|
| Depth table | One line per contig: name, length, total depth, and a mean and variance per library |
| `<o>.1.fa` and so on | The bins |

## When to use it

Use it nearly always. It's a good default, and on its own, it often gives the largest number of good bins. It makes use of many samples, but it also works with one.

## In this pipeline

The rule `assemble__metabat2__run` makes BAM files, computes the depths and runs:

```bash
metabat2 -i {input.contigs} -a "$depth" -o {output}/bin -m {params.min_contig} -t {threads} -v
```

`-m 1500` is the smallest value MetaBAT2 accepts. Also note that MetaBAT2 drops bins smaller than 200 kb by default, and it doesn't report unbinned contigs.

## Pitfalls

- **`jgi_summarize_bam_contig_depths` needs sorted BAM files.** The mapping rule sorts them.
- **No bins.** On a small or poor assembly, it can produce nothing at all without any error, and this is a valid result. Look at the log.
- **Differences between runs.** A random seed influences the result. `--seed` makes runs repeatable.

## Reference

Kang DD, et al. (2019). MetaBAT 2: an adaptive binning algorithm for robust and efficient genome reconstruction from metagenome assemblies. *PeerJ*. <https://doi.org/10.7717/peerj.7359>
