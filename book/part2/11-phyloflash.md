# phyloFlash {#sec-tool-phyloflash}

## What it does

phyloFlash looks at the small-subunit ribosomal RNA genes (SSU rRNA, 16S in Bacteria and Archaea, 18S in eukaryotes) in a metagenome. These genes are the classic marker of microbial taxonomy, and their databases are huge. So this tool links your metagenome to decades of work with amplicons. Unlike most of the other profilers here, it sees all three domains of life, and so eukaryotes as well.

## How it works

1. It maps the reads against the SILVA database of SSU rRNA with BBmap, and it extracts those that hit.
2. It gets a taxonomy for these reads from their best hit, which gives a quick profile.
3. It assembles the extracted reads with SPAdes to get full-length SSU sequences, and it compares them with the database.
4. It estimates the abundance of each assembled sequence, and how much of the SSU reads the assembled sequences explain.

## Input

Reads as FASTQ (`-read1`, `-read2`), and a database folder (`-dbhome`) that was prepared with a script for it, from SILVA. Here this is version 138.2. It also needs a library name (`-lib`).

## Output

| File | Content |
|------|---------|
| `<lib>.phyloFlash.html` | The report for a browser, the best place to start |
| `<lib>.phyloFlash.log` | The log, with a summary |
| `<lib>.phyloFlash.extractedSSUclassifications.csv` | Taxonomy from the mapped reads, with counts |
| `<lib>.spades_rRNAs.final.fasta` | Assembled SSU sequences |
| `<lib>.phyloFlash.tar.gz` | The other results, as an archive |

## When to use it

Use it when you want to compare with amplicon studies, when you have many eukaryotes or want to see them at all, or when you want full-length rRNA sequences from a metagenome. It's a good second opinion on the composition of a sample.

Be careful with abundances. The number of rRNA gene copies varies between organisms, from one to more than ten, so counting these genes doesn't count cells. And since the gene is highly conserved, the assembly can merge similar species, and it can create chimeras.

## In this pipeline

The rule `read_annotate__phyloflash__run` runs it on the clean reads of each library:

```bash
phyloFlash.pl -dbhome {input.phyloflash_dbs} \
              -lib {params.lib} -CPUs {threads} \
              -read1 {input.forward_} -read2 {input.reverse_} \
              -almosteverything
```

`-almosteverything` switches on the optional analyses, except EMIRGE, a slower alternative for reconstructing sequences.

phyloFlash writes its results to the current folder, here the project folder, so the rule moves them afterwards. If a job is killed, files named after the library can stay behind in the project folder.

The library name has an underscore instead of the usual dot, as in `ERR2019410_lib1`.

`read_annotate__phyloflash__condense` concatenates the logs into `phyloflash_all.log`.

## On real data

This book has no real output of this tool yet. @sec-tutorial-waiting says why, and it will come from a complete run on a cluster.

## Pitfalls

- **Host rRNA.** Eukaryotic SSU reads of the host would dominate, if host reads were still there. This pipeline removes them first, so this isn't an issue here, as long as the host genome is in `features.yaml` and it contains those genes.
- **Read length.** Very short reads don't work well. The tool has a lower limit on read length, and it warns about it.
- **The share of SSU reads is small.** Usually it's well below 1% of reads. So with little sequencing, there may be too few reads for an assembly, and the report will be empty.

## Reference

Gruber-Vodicka HR, Seah BKB, Pruesse E (2020). phyloFlash: Rapid Small-Subunit rRNA Profiling and Targeted Assembly from Metagenomes. *mSystems*. <https://doi.org/10.1128/mSystems.00920-20>
