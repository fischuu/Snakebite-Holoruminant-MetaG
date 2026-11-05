# Bowtie2 {#sec-tool-bowtie2}

## What it does

Bowtie2 aligns short reads against a reference sequence: for each read, it finds where in the reference it fits best. This is called read mapping. The pipeline uses it three times, with different questions: which reads come from the host, how well does each contig get covered, and how many reads fall on each MAG.

## How it works

A reference genome can have billions of bases, and there are hundreds of millions of reads. Comparing them directly would take forever. So Bowtie2 first builds an **index** of the reference, based on the FM index, a compressed structure that lets you look up short sequences very quickly while taking little memory.

To map a read, Bowtie2 takes short pieces, the seeds, of the read, and finds where they occur in the index. Then it extends the promising places with an alignment that allows mismatches and gaps. Each alignment gets a score, and the best one is reported.

If a read fits well in several places, Bowtie2 reports one of them, chosen at random among the best. It says how sure it is with the **mapping quality**: 0 means that there are equally good places elsewhere, and high values mean that the place is unique.

There are two modes. In the default `--end-to-end` mode, the whole read must fit. In `--local` mode, the ends of a read may be left out. This pipeline uses the default.

For pairs, Bowtie2 also checks whether the two mates fit together: facing each other at a suitable distance. Such a pair is called concordant, or properly paired.

## Input

| Step | Input |
|------|-------|
| `bowtie2-build` | FASTA with the reference |
| `bowtie2` | The index (`-x`) and FASTQ with the reads (`-1`, `-2`) |

## Output

`bowtie2-build` writes six files that end in `.bt2`, or `.bt2l` for very large references. All of them together are the index, and you name it by their common prefix.

`bowtie2` writes SAM to the standard output, usually piped straight into `samtools`, since this format takes a lot of disk space. The reads that don't map are also in the output, marked with a flag. This matters here, as these are the reads the pipeline wants to keep after mapping to a host.

At the end, Bowtie2 prints a summary to the standard error, with the share of pairs that aligned once, more than once and not at all. The pipeline's logs contain it.

## When to use it

Bowtie2 is a good choice for reads of 50 bases up to a few hundred bases, against a reference that is similar to the reads. It suits genomes and metagenomes well.

Use something else in these cases:

- **RNA-seq against a genome.** Reads span exons, and you need a splice-aware tool such as HISAT2 or STAR.
- **Long reads.** minimap2 is the tool for these.
- **Reads that are far from the reference**, as in a comparison between species. Bowtie2 works on DNA, and for distant protein-level comparisons you need DIAMOND, see @sec-tool-diamond.

BWA-MEM is a common alternative with similar results for many purposes.

## In this pipeline

The pipeline uses it with mostly default options, in three places:

| Rule | Reference | Question |
|------|-----------|----------|
| `preprocess__bowtie2__build`, `preprocess__bowtie2__map` | Each host genome | Which reads come from the host? |
| `assemble__bowtie2__build__run`, `assemble__bowtie2__map` | Each assembly | How well is each contig covered? |
| `quantify__bowtie2__build`, `quantify__bowtie2__map` | The MAG catalogue | How much of each genome is in each sample? |

All mapping rules add a read group, `--rg-id` and `--rg`, which marks the reads with their library and sample. Some tools need this, and it also lets you see later where a read came from.

The output goes straight into `samtools sort`, to save disk space, as @sec-module-preprocess shows.

## On real data

@sec-tutorial-preprocess and @sec-tutorial-assemble show real output of this tool, and how to read it.

## Pitfalls

- **The prefix isn't a file.** `-x` wants the common prefix of the index files, and not a file name. The pipeline uses an empty placeholder for this, and you shouldn't delete it, or Snakemake will rebuild the index.
- **Mapping rate and reference.** A low mapping rate against an assembly can mean that much of the community wasn't assembled. It doesn't mean that Bowtie2 failed.
- **Multi-mapping.** A read in a repeat or a conserved gene is reported at just one place, chosen at random. With a catalogue of similar genomes, this can blur the counts between them. This is one reason to dereplicate.
- **Threads and memory.** Each mapping scales well with threads, and it doesn't take much memory, but the following `samtools sort` does.
- **Host removal isn't perfect.** Reads that come from parts of the host missing from the reference stay in the data. Reads of microbes that are similar to a host sequence are removed by mistake.

## Reference

Langmead B, Salzberg SL (2012). Fast gapped-read alignment with Bowtie 2. *Nature Methods*. <https://doi.org/10.1038/nmeth.1923>
