# NCycDB {#sec-tool-ncyc}

## What it does

NCycDB is a curated database of the genes of the nitrogen cycle, along with a script that profiles samples against it. Nitrogen matters in a rumen, in soil, and in many other places: fixation, nitrification, denitrification, and the conversions between them. General databases can blur these gene families. For example, some of them are close relatives that do different things. NCycDB was built to keep these apart.

## How it works

The database holds the protein sequences of 68 gene families of the nitrogen cycle, collected and curated by hand. It also contains homologs from related families. They don't count, but they catch reads that would otherwise be assigned wrongly to a family of interest.

The Perl script `NCycProfiler.PL` compares each sample with the database, using a search tool such as DIAMOND, keeps the best hits, and adds up the counts per gene family. It normalizes them by the sequencing depth of each sample.

## Input

| Option | Content |
|--------|---------|
| `-d` | Folder with the sequence files |
| `-f` | Their ending, such as `fq.gz` or `fa` |
| `-s` | The type of the sequences, `nucl` or `prot` |
| `-si` | A table of sample names and files |
| `-m` | The search tool, here `diamond` |
| `-db_faa`, `-db_folder` | The database and where to find its files |

## Output

One table, with gene families as rows and samples as columns, normalized. The result file is what `-o` names, and `-of` is the folder for its working files.

## When to use it

Use it when the nitrogen cycle is part of your question. For a general view of function, other tools are a better start. This one is a specialized addition, and that's why it isn't in the main targets.

## In this pipeline

It runs twice, and both are outside the default run. You call them with `read_annotate_extra` and `contig_annotate_extra`.

| Rule | Input | Mode |
|------|-------|------|
| `read_annotate__ncyc__prepare_input`, `read_annotate__ncyc__run` | Clean reads | `-s nucl` |
| `contig_annotate__ncyc__prepare_input`, `contig_annotate__ncyc__run` | Proteins from Prodigal | `-s prot` |

`workflow/scripts/prepare_ncyc_inputs.sh` writes the sample table. The Perl script comes with the pipeline, in `workflow/scripts/NCycProfiler.PL`, so that the version is fixed. The database is the entry `ncyc` in `features.yaml`, and all its files have to be in the same folder as `NCyc_100.faa`, as the rule assumes.

## On real data

@sec-tutorial-read-annotate and @sec-tutorial-contig-annotate show real output of this tool, and how to read it.

## Pitfalls

- **All samples at once.** Both rules run all samples in one job. It has to finish as a whole, so a failure late in the job costs the time for all samples.
- **Reads versus proteins.** The two runs measure different things: one counts reads per family, the other counts predicted genes per family. A high abundance of a gene in the reads doesn't need to mean many different genes.
- **Fixed database file name.** `features.yaml` points to one FASTA file, and the rule derives the folder from it.

## Reference

Tu Q, Lin L, Cheng L, Deng Y, He Z (2019). NCycDB: a curated integrative database for fast and accurate metagenomic profiling of nitrogen cycling genes. *Bioinformatics*. <https://doi.org/10.1093/bioinformatics/bty741>
