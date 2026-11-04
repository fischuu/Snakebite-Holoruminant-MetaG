# sylph {#sec-tool-sylph}

## What it does

sylph looks for known genomes in a metagenome. For each genome in its database, it estimates how similar the closest organism in your sample is (its ANI), and how abundant it is. It's very fast and needs little memory, and it works even for organisms that have very low coverage.

## How it works

sylph doesn't align reads. It uses a small sample of the k-mers of each genome and of the reads, a sketch. It then compares them: if the sample contains an organism identical to a genome in the database, then all k-mers of that genome should show up. If the organism differs slightly, fewer do.

The problem at low coverage is that many k-mers are missing just because they weren't sequenced, and this would look like a low similarity. sylph corrects for this: from how often the k-mers that are present are seen, it estimates the true coverage, and from that the expected share of missing k-mers. This lets it estimate a reliable ANI even at a coverage of well below 1x.

From these values it computes the abundance of each genome, in two forms: by the number of cells (the taxonomic abundance) and by the amount of sequence (the sequence abundance).

## Input

A database of sketched genomes (`.syldb`) and reads, either as FASTQ or as prepared sketches. `-1` and `-2` take paired reads.

## Output

`sylph profile` writes a table with one line per genome that it detects. These are the most useful columns:

| Column | Content |
|--------|---------|
| `Sample_file` | The reads |
| `Genome_file` | The genome in the database |
| `Taxonomic_abundance` | Percentage by number of cells |
| `Sequence_abundance` | Percentage by amount of sequence |
| `Adjusted_ANI` | Estimated ANI to the closest organism in the sample |
| `Eff_cov` | Estimated coverage |
| `ANI_5-95_percentile` | How certain the ANI is |
| `Contig_name` | A contig of this genome, whose name often holds the taxonomy |

## When to use it

Use it for a fast and accurate profile on the level of species, if your organisms are represented in the database. The `Adjusted_ANI` is a helpful extra, because it tells you how close your organism is to the reference. A value around 95% or below means that it's a relative and not that species.

Like every database method, it doesn't see what isn't in there. It only looks at the genomes in the database, and it has nothing to say about novel groups. For this, SingleM is the better tool, and they complement each other.

## In this pipeline

The rule `read_annotate__sylph_profile` runs one call per library, against the database in `features.yaml`, by default GTDB R220:

```bash
sylph profile {input.db} -1 {input.forwards} -2 {input.reverses} -t {threads} > {output}
```

There's no step that combines the libraries. You get one table per library, and they are simple to join yourself by `Genome_file`.

The rule still contains a commented part for testing the escalation, and you can ignore it.

## Pitfalls

- **The genome names are file names.** To get a taxonomy, you need the metadata of the database. For GTDB, the accession in `Genome_file` is the link.
- **Abundance refers to what was found.** The percentages add up to 100 over the detected genomes, not over your whole sample. If much of the community isn't in the database, the percentages are too high in absolute terms.
- **A database of the wrong type.** Sketches made for short reads and for long reads are built with different settings. Use the right one.

## Reference

Shaw J, Yu YW (2024). Rapid species-level metagenome profiling and containment estimation with sylph. *Nature Biotechnology*. <https://doi.org/10.1038/s41587-024-02412-y>
