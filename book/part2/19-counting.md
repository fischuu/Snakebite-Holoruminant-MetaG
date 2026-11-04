# CoverM {#sec-tool-coverm}

## What it does

CoverM computes how much of each genome or contig is covered by reads, from alignments. It's the tool that turns a mapping into the abundance table. It knows about genomes that consist of many contigs, and it offers a long list of ways of measuring.

## How it works

It reads an alignment, and it counts per contig. In `coverm genome`, it adds up the contigs of each genome. To know which contigs form a genome, it can take a list, a folder of FASTA files, or simply a character in the contig names, the separator `-s`.

## Input

BAM files (`-b`), sorted by position, or reads with a reference, in which case it does the mapping itself. In `genome` mode, it also needs one way to tell which contig belongs to which genome.

## Output

A table with one row per genome or contig, and one column per sample and method. The first column holds the name. The available methods include:

| Method (`-m`) | Meaning |
|---------------|---------|
| `count` | Number of mapped reads |
| `covered_bases` | Number of bases with at least one read |
| `length` | Length of the genome or contig |
| `mean` | Average depth |
| `trimmed_mean` | Average depth without the highest and lowest 5% of the positions |
| `relative_abundance` | Percentage of mapped reads on this genome |
| `rpkm` | Reads per kilobase and million reads |
| `tpm` | Like RPKM, normalized so that a sample sums to one million |

There's more: <https://github.com/wwood/CoverM#calculation-methods>.

`--min-covered-fraction` matters in `genome` mode. A genome counts as present only if this percentage of it is covered, and otherwise its value is set to 0. By default this is 10. The idea is that a few reads can map to a genome by chance, through a conserved gene, for example, without that genome being in the sample.

## When to use it

Use it for quantifying genomes from a catalogue. For gene-level counts, you need a tool that uses gene positions, such as featureCounts.

## In this pipeline

The rules are in @sec-module-quantify. `samtools view` first turns CRAM into BAM, keeping only mapped reads, and then CoverM reads it from a pipe:

```bash
samtools view -1 -F 4 -T {input.catalogue} {input.alignment} \
    | coverm genome -b /dev/stdin -m {wildcards.method} -s {params.settings[separator]} \
        --min-covered-fraction {params.settings[min_covered_fraction]} \
    > {output}
```

Each method runs as its own job, per library, and `workflow/scripts/coverm_wide_table.R` then joins them into one table. The default methods are `count`, `covered_bases`, `length` and `tpm`.

**Note that `min_covered_fraction` is 0 here**, so even a genome with a single read gets a value. You'll want to filter these yourself, using `covered_bases` divided by `length`.

## On real data

@sec-tutorial-quantify shows real output of this tool, and how to read it.

## Pitfalls

- **`min_covered_fraction`**, as above.
- **Conserved regions.** With 0 as the fraction, conserved genes produce low values for genomes that aren't there. A genome with a low covered fraction shouldn't be counted as present.
- **The separator.** All contig names need the `@`, and the genome is what's left of it. The pipeline's names take care of that.
- **Which measure?** Use `count` for statistical tests, which want raw counts, and `tpm` or `relative_abundance` for descriptions.

## Reference

Aroney STN, et al. (2025). CoverM: read alignment statistics for metagenomics. *Bioinformatics*. <https://doi.org/10.1093/bioinformatics/btaf147>

# featureCounts {#sec-tool-featurecounts}

## What it does

featureCounts counts how many reads fall on each gene. It takes alignments and a table of gene positions, and it writes a table of counts. It's part of the Subread package, and it's a very common tool in RNA-seq, but it's equally useful here.

## How it works

For each read or fragment, it finds the features it overlaps. If it overlaps exactly one, this feature gets a count. By default, a read that overlaps several features isn't counted, nor is a read that maps to several places. This is cautious, and it can be changed with `-O` and `-M`.

## Input

| Option | Content |
|--------|---------|
| `-a` | The annotation, as GTF or GFF |
| `-F` | The format |
| `-t` | Which type of feature to count, from column 3 of the file |
| `-g` | Which attribute names the gene, from column 9 |
| `-p` | The data are paired. In this version, it counts fragments instead of reads |
| The last arguments | One or several BAM files |

It reads BAM and SAM, not CRAM.

## Output

| File | Content |
|------|---------|
| `-o` | The counts: gene, contig, start, end, strand, length, and one column per BAM file |
| `<o>.summary` | How many reads were assigned, and why the others weren't |

The first line of the count table is a comment that holds the command. Look at the `.summary` file: `Assigned` is what counts, and a high value of `Unassigned_NoFeatures` means that many reads don't fall on any gene.

## When to use it

Use it for counting reads on genes. Compared with a mapper-level tool like CoverM, it knows about the position of genes. It's very fast.

## In this pipeline

The rule `contig_annotate__featurecounts__run` counts per library and assembly, as @sec-module-contig-annotate shows:

```bash
featureCounts -p -T {threads} -F GFF3 \
              -a {input.gtf} -o {output.file} \
              -t CDS -g ID \
              {input.bam}
```

The file with the positions comes from Prodigal, which marks genes as `CDS` and gives each an `ID` like `1_5`, the fifth gene on the first contig in the file. So the names in this table differ from the names in the protein file. Each gene's ID is built from the position of the contig in the file. To join the tables, use the contig and the gene number.

The image `subread` holds version 2.0.1.

## On real data

@sec-tutorial-contig-annotate shows real output of this tool, and how to read it.

## Pitfalls

- **`-p` changed its meaning.** In version 2.0.2 and later, `-p` only says that the data are paired, and `--countReadPairs` is needed to count fragments. So if you change the image, then check this, or your counts could double.
- **Multi-mapped reads** aren't counted. In a metagenome with very similar genes, this can undercount them.
- **Annotation and BAM must agree on the contig names.** Otherwise, everything is unassigned.

## Reference

Liao Y, Smyth GK, Shi W (2014). featureCounts: an efficient general purpose program for assigning sequence reads to genomic features. *Bioinformatics*. <https://doi.org/10.1093/bioinformatics/btt656>
