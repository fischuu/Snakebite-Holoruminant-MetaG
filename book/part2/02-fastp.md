# fastp {#sec-tool-fastp}

## What it does

fastp cleans FASTQ files. In a single run, it removes adapters, filters out poor reads, trims unwanted tails, and writes a report on what it did. Earlier workflows needed several programs for this, such as Trimmomatic or Cutadapt plus a quality tool. fastp does it in one step, and it's fast because it's written in C++ and uses many threads.

## How it works

fastp goes through the reads and applies these steps to each read or pair.

**Adapter trimming.** The sequencing machine reads a fragment from its end. If the fragment is shorter than the read length, the machine reads on into the adapter on the other side. Then the end of the read isn't biological.

For pairs, fastp can find this without knowing the adapter: if the two mates overlap, then the position where they extend past each other shows where the adapter begins. You can also give the adapter sequences directly, and this pipeline does that.

**Quality filtering.** By default, a read is thrown away if more than 40% of its bases have a quality below Q15, or if it has more than 5 unknown bases (`N`). If one mate of a pair fails, the other can be kept as an unpaired read. Note that by default, fastp doesn't trim low-quality ends, it only judges whole reads. Trimming with a sliding window has to be switched on with options such as `--cut_tail`.

**Length filtering.** A read that's too short after trimming is thrown away, by default under 15 bases.

**Tail trimming.** Some sequencers (with two-color chemistry, such as NextSeq and NovaSeq) report `G` when they see no signal, so poor reads can end with a long run of `G`. `--trim_poly_g` removes this, and fastp turns it on by itself for those machines. `--trim_poly_x` removes tails of any other single base, such as the `A` tail of RNA.

## Input

One FASTQ file for single reads, or two for pairs, with or without gzip. Optionally the adapter sequences.

## Output

| Option | File | Content |
|--------|------|---------|
| `--out1`, `--out2` | FASTQ | The cleaned pairs. Still in the same order, so that mates stay matched |
| `--unpaired1`, `--unpaired2` | FASTQ | Reads whose mate was thrown away |
| `--html` | HTML | The report for a browser |
| `--json` | JSON | The same report as data |

The JSON file is what you want for summaries over many samples. Its most useful fields are:

| Field | Content |
|-------|---------|
| `summary.before_filtering`, `summary.after_filtering` | Reads, bases, Q20 and Q30 rates, GC content |
| `filtering_result` | Reads that passed, and why the others failed: `low_quality_reads`, `too_many_N_reads`, `too_short_reads` |
| `adapter_cutting.adapter_trimmed_reads` | How many reads had adapter |
| `duplication.rate` | The estimated share of duplicates |

## When to use it

Use it as the first step on nearly any short-read data from Illumina. It's a sensible default, because it's fast and its choices are moderate.

Don't use it for long reads from PacBio or Nanopore, which have other properties and other tools. And if your data are amplicons with primers, you need to remove the primers, which is a separate matter from adapters. Cutadapt handles that better.

## In this pipeline

The rule `preprocess__fastp__run` runs it once per library, as @sec-module-preprocess shows in detail. The choices made there are:

- **Adapters** come from the sample table, so you can have different adapters per library. Using known adapters is safer than auto-detection, which only works for reads that overlap.
- **`--length_required 25`**, as Nonpareil needs reads of at least that length.
- **`--trim_poly_g --trim_poly_x`**, to remove tails of a single base.
- **`--verbose`**, so that the log shows the progress.
- **No sliding-window trimming**, which keeps this step close to fastp's defaults. If your quality falls sharply at the ends of the reads, you could add `--cut_tail` under `extra` in `params.yaml`.

The rule lets fastp write plain files and then compresses them with `bgzip`, as this is both faster and safe. It tests the result with `gzip --test`.

The unpaired files are kept, but no later rule reads them.

## Pitfalls

- **Wrong adapters.** If the sequences in your sample table are wrong, nothing is trimmed, and there's no error. Check the adapter curve in the FastQC report after fastp. It's flat if the adapters are gone.
- **Too many reads lost.** Losing a few percent is normal. If you lose a large share, look at `filtering_result`. Low-quality reads point to the sequencing run, and too-short reads point to very short fragments in the library.
- **`--unpaired1` and `--unpaired2` pointing to the same file.** This would be valid for fastp, but then you could no longer tell the two sets apart. This pipeline keeps them separate.
- **Threads.** More than a certain number of threads doesn't speed it up, because reading and compressing limit it. That's another reason why this pipeline compresses separately.

## Reference

Chen S, Zhou Y, Chen Y, Gu J (2018). fastp: an ultra-fast all-in-one FASTQ preprocessor. *Bioinformatics*. <https://doi.org/10.1093/bioinformatics/bty560>
