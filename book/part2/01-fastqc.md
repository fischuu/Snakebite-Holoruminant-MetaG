# FastQC {#sec-tool-fastqc}

## What it does

FastQC reads a FASTQ file and writes a report about its quality. It doesn't change your data. It's a quick look at whether a sequencing run looks healthy, and whether the following steps have something to fix.

The report consists of a number of checks, each with a mark of pass, warning or fail.

| Check | What it shows |
|-------|---------------|
| Per base sequence quality | The quality along the read. It usually falls toward the end |
| Per tile sequence quality | Quality by position on the flow cell, which shows local problems in a run |
| Per sequence quality scores | Whether a group of reads is poor overall |
| Per base sequence content | The share of A, C, G and T along the read |
| Per sequence GC content | The GC distribution over all reads, compared to a normal distribution |
| Per base N content | How often a base couldn't be called |
| Sequence length distribution | Whether all reads have the same length, for example before and after trimming |
| Sequence duplication levels | How often the same sequence occurs |
| Overrepresented sequences | Sequences that occur far too often, such as adapters |
| Adapter content | How much adapter remains, by position |

## Input

One or several sequence files. FASTQ with or without gzip is the usual case, and SAM and BAM also work. Each file gets its own report. Paired reads aren't connected in any way, so you get two reports per library.

## Output

| File | Content |
|------|---------|
| `<name>_fastqc.html` | The report, a single file that you open in a browser |
| `<name>_fastqc.zip` | The same as data, including a text file with all numbers, which is useful for scripts and for MultiQC |

## When to use it

Always, at the start, and again after trimming. It takes a few minutes and it can save weeks. Compare the two reports: the adapter curve should be gone, and the quality at the ends of the reads should be better.

With many samples, reading single reports gets tedious. MultiQC, a separate tool, combines many reports into one, and it reads the zip files. It's not part of this pipeline, but you can run it on the results folder.

## Reading it for a metagenome

**The marks were designed with a single genome in mind, so several fail for good reasons in a metagenome.** Don't be alarmed, and learn what is normal for your samples:

- **Per sequence GC content** often fails, because a community is a mix of organisms with different GC content. Several peaks are normal. You can even learn something from them. A sharp peak that doesn't belong may be a contaminant, or a very dominant organism.
- **Sequence duplication levels** can fail because abundant organisms really are sequenced many times over. In a metagenome, duplicates don't have to be an artifact.
- **Per base sequence content** often shows wobbles in the first ten or so bases of a read. This comes from the library preparation and it's common.

What does deserve attention:

- Quality that falls early in the read, and in the forward read as well
- Adapter content that rises toward the end of the read. Normally, this is what you trim
- A strange overrepresented sequence. Search for it online or in a database, as it could be a primer or a contaminant
- Reports that look very different from the other samples of the same run

## In this pipeline

The generic rule `helpers__fastqc` makes a report for any file ending in `.fq.gz`, as @sec-module-helpers explains. Three targets ask for it:

- `reads__fastqc` for the raw reads
- `preprocess__fastqc__fastp` for the reads after trimming
- `preprocess__fastqc__nonhost` for the reads after each host

The rule simply calls `fastqc {input}`, which runs with one thread per file.

## On real data

@sec-tutorial-reads shows the real report of this tool on 100,000 reads, and @sec-tutorial-preprocess shows it after trimming. Its `FAIL` for the GC content is an example of what the section above says about metagenomes.

## Pitfalls

- **Judging a metagenome by the marks alone.** See above.
- **Memory.** FastQC is a Java program that reserves a fixed amount of memory per file. This is no issue for short reads. For very long reads it can be too little.
- **The folder must exist.** On its own, FastQC refuses to write to a folder that doesn't exist. By default, it writes the report next to the input, as here.

## Reference

Andrews S. FastQC: a quality control tool for high throughput sequence data. <https://www.bioinformatics.babraham.ac.uk/projects/fastqc/>. There's no paper to cite, so cite the website with the version.
