# SAMtools and friends {#sec-tool-samtools}

## What it does

SAMtools is the standard toolbox for alignment files. It reads, converts, sorts, indexes, filters and summarizes them. It's a set of subcommands, and the pipeline uses many of them. HTSlib, the library behind it, also provides `bgzip`, and this chapter covers that too, along with the other small helpers, `pigz` and `parallel`.

## The formats

### SAM

SAM is a plain text format, with one line per read. These are its most important columns:

| Column | Name | Content |
|--------|------|---------|
| 1 | `QNAME` | Name of the read |
| 2 | `FLAG` | What is known about the read, see below |
| 3 | `RNAME` | The reference sequence it mapped to |
| 4 | `POS` | The position on it |
| 5 | `MAPQ` | Mapping quality |
| 6 | `CIGAR` | How it aligns: matches, insertions, deletions |
| 10 | `SEQ` | The bases |
| 11 | `QUAL` | Their qualities |

### The flag

The flag is a number that combines yes-or-no statements about a read, each with its own bit. You will see these often:

| Value | Meaning |
|-------|---------|
| 1 | The read is part of a pair |
| 2 | Both mates are mapped as expected, a proper pair |
| 4 | This read is unmapped |
| 8 | Its mate is unmapped |
| 16 | This read is on the reverse strand |
| 256 | Not the main alignment of this read |
| 2048 | A supplementary alignment |

`samtools view` filters by them: `-f 12` keeps the reads with both 4 and 8, so reads with both mates unmapped. `-F 4` drops the reads with 4, leaving the mapped ones. The pipeline uses both of these.

### BAM and CRAM

BAM is SAM in a compressed binary form. CRAM goes further: it stores only how each read differs from the reference, which makes it clearly smaller. There's a price: **to read a CRAM file, you need the very same reference sequence**, so if the reference is lost or changed, the file is useless. The pipeline uses CRAM to save space, and it's why `--reference` or `-T` appears in so many commands.

Both can have an index, `.bai` for BAM and `.crai` for CRAM, for jumping to a certain place. The file has to be sorted by position for this.

## The subcommands used here

| Command | What it does | Where |
|---------|--------------|-------|
| `samtools sort` | Sorts by position, or by name with `-n` | All mapping rules |
| `samtools view` | Filters and converts | Everywhere |
| `samtools index` | Makes `.bai` or `.crai` | `helpers__samtools__index_bam`, `helpers__samtools__index_cram` |
| `samtools faidx` | Indexes a FASTA for random access | `helpers__samtools__faidx_fa`, `helpers__samtools__faidx_fagz` |
| `samtools fastq` | Turns alignments back into FASTQ | `preprocess__bowtie2__extract_nonhost__run` |
| `samtools flagstats` | A short summary by flags | `helpers__samtools__flagstats_cram` |
| `samtools stats` | A long summary | `preprocess__samtools__stats_cram`, `quantify__samtools__stats_cram` |
| `samtools idxstats` | Reads per reference sequence | `helpers__samtools__idxstats_cram`, `preprocess__bowtie2__map` |
| `samtools coverage` | Coverage per reference sequence | `assemble__maxbin2__run` |

## Reading the summaries

`samtools flagstats` prints a few lines, which are quick to read. Mostly you look at the percentage of mapped reads, and of properly paired ones.

`samtools stats` writes many sections. Each line starts with a code, and `grep ^SN` gets the summary numbers: raw total sequences, reads mapped, error rate, average length and insert size. The other sections hold distributions, and `plot-bamstats` turns them into figures.

`samtools idxstats` writes one line per reference sequence: its name, its length, the mapped reads and the unmapped reads.

`samtools coverage` also has one line per sequence, with these columns:

| Column | Name | Content |
|--------|------|---------|
| 1 | `rname` | Sequence |
| 2, 3 | `startpos`, `endpos` | The range |
| 4 | `numreads` | Number of reads |
| 5 | `covbases` | Number of covered bases |
| 6 | `coverage` | Percentage of covered bases |
| 7 | `meandepth` | Average depth |
| 8, 9 | `meanbaseq`, `meanmapq` | Average qualities |

## The compressors

### bgzip

`bgzip` compresses files in small blocks. The result is a valid gzip file, so any tool reads it, but an index can jump to any block. `samtools faidx` needs that for compressed FASTA files. So if you get an error from `faidx` about a compressed file, the file probably was made with plain `gzip`. `bgzip` also works with several threads.

### pigz

`pigz` is `gzip` with several threads. It's faster, and the result is a normal gzip file. The pipeline uses it wherever it doesn't need an index, often together with `tar`, for packing the working folders. Give it its input through a plain pipe or a file name, but don't write through `>(pigz ...)`, as @sec-process-substitution-trap explains.

### GNU parallel

`parallel` runs a command many times at once. The pipeline uses it for Prodigal, which only has one thread: with `--pipe --recstart '>'`, it cuts the stream of FASTA records into blocks, and it gives each block to one Prodigal. See `assemble__magscot__prodigal`.

## On real data

@sec-tutorial-preprocess shows real output of this tool, and how to read it.

## Pitfalls

- **Memory of `samtools sort`.** `-m` is per thread. With `-m 8G` and 20 threads, it can take 160 GB, so check that this fits into the job. This is a common reason for jobs being killed, and `params.yaml` has this setting for each module.
- **Temporary files of `sort`.** It writes temporary files next to its output, and a killed job leaves them behind. Some rules remove them before a new start.
- **A CRAM without its reference.** Keep the reference. Otherwise, you can't read the file any more.
- **CRAM and long contig names.** Very long names in the header can lead to errors with CRAM. In this case, set `out_type: bam` under `assemble: samtools` in `params.yaml`.
- **A broken pipe.** In `samtools view | head`, `head` stops reading, and `samtools view` then fails with a broken pipe. In strict mode, that stops a rule, as @sec-strict-mode explains.

## Reference

Danecek P, et al. (2021). Twelve years of SAMtools and BCFtools. *GigaScience*. <https://doi.org/10.1093/gigascience/giab008>
