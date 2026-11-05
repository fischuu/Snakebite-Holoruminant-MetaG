# The tools at a glance {#sec-tools-overview}

The pipeline itself computes very little. Nearly all the work is done by about forty programs, each written by other people, and each with its own ideas about input, output and memory. To understand your results, and to know what to do when something fails, you have to know these programs. This part has a chapter for each.

## How to read these chapters

Every chapter has the same structure:

- **What it does**, and the idea behind it, as far as you need that to use it well
- **Input** and **output**, in what form they usually come
- **When to use it**, and when something else would be the better choice
- **In this pipeline**: which rule runs it, how, and why it was chosen
- **Pitfalls**, the things that commonly go wrong or get misread
- **Reference**, the paper to cite

You don't have to read this part from beginning to end. When a module in Part III mentions a tool, come here for the background. The real output of the tools on real data is in Part IV, in @sec-tutorial, because it makes more sense in the order in which it's produced. The chapters here describe the file formats in general.

## Please cite the tools

Each tool is someone's scientific work, and a citation is how that work gets recognized. If you publish results from this pipeline, cite the tools you used, with the version. The reference at the end of each chapter was checked against the publisher's record when this book was written. The file `citations.tct` in the repository has more of them.

## Some terms you will meet

**Read.** A short piece of sequenced DNA, here about 100 to 150 bases long. Paired-end sequencing reads a fragment from both ends, which gives two reads, called mates, a few hundred bases apart.

**k-mer.** A piece of exactly k bases. A read of 100 bases contains 100 − k + 1 overlapping k-mers. Many tools work with k-mers, as it's much faster to look up short words than to align whole sequences.

**Contig.** A longer sequence that an assembler built from overlapping reads.

**Bin.** A group of contigs that likely come from the same organism.

**MAG.** A metagenome-assembled genome, a bin of good quality.

**Coverage or depth.** How many reads cover a base on average.

**Completeness and contamination.** How much of a genome is there, and how much of it comes from other organisms. Usually estimated with marker genes.

**ANI.** Average nucleotide identity. It tells you how similar two genomes are, and 95% is the usual limit for one species.

**HMM.** A hidden Markov model. Here it's a statistical profile of a family of proteins, which can recognize distant members better than a comparison with a single sequence can.

## The file formats

Most of the formats are shared between many tools, so it's enough to explain them once.

**FASTQ** holds reads with their quality, with four lines per read: a name that starts with `@`, the bases, a `+`, and one character per base for its quality. The character stands for a Phred score Q, where the chance that the base is wrong is 10^(−Q/10). So Q20 means 1 wrong base in 100, and Q30 means 1 in 1000.

**FASTA** holds sequences, with a name line that starts with `>`, and then the sequence, on one or several lines.

**SAM, BAM and CRAM** hold alignments of reads against a reference. SAM is text, BAM is its compressed binary form, and CRAM stores only the differences to the reference, so it's smaller and it needs the reference to be read. See @sec-tool-samtools.

**GFF and GTF** describe the positions of features such as genes on a sequence, with one feature per line.

**TSV** is a plain table, with tabs between the columns.

## The containers

`config/.docker.yml` names one image per key, and a rule uses it as `docker["key"]`:

| Key | Image | Used for |
|-----|-------|----------|
| `reads` | `fischuu/hrp_reads:0.2` | Linking the reads |
| `reference` | `fischuu/hrp_reference:0.1` | Recompressing the host genomes |
| `helpers` | `fischuu/hrp_helpers:0.1` | FastQC and SAMtools in the generic rules |
| `preprocess` | `fischuu/hrp_preprocess:0.8` | fastp, Kraken2, MetaPhlAn, Nonpareil, SingleM, SAMtools |
| `bowtie2` | `fischuu/hrp_bowtie2:0.1` | Host removal and mapping to the catalogue |
| `assemble` | `fischuu/hrp_assemble:0.2` | Assemblers, MaxBin2, MetaBAT2, MAGScoT, dRep, Prodigal, HMMER |
| `concoct` | `fischuu/hrp_concoct:0.1` | CONCOCT |
| `quantify` | `fischuu/hrp_quantify:0.2` | CoverM |
| `subread` | `fischuu/subread:2.0.1-0.1` | featureCounts |
| `mag_annotate` | `fischuu/hrp_annotate:0.4` | QUAST, Bakta, PhyloPhlAn, Proteinortho, DIAMOND, nCycDB |
| `checkm2` | `fischuu/hrp_checkm2:0.1` | CheckM2 |
| `gtdbtk` | `fischuu/hrp_gtdbtk:0.3` | GTDB-Tk |
| `dram` | `fischuu/hrp_dram:0.4` | DRAM |
| `camper` | `fischuu/hrp_camper:0.1` | CAMPER |
| `eggnog` | `fischuu/hrp_eggnog:0.1` | eggNOG-mapper on the catalogue, eggNOG 7 |
| `humann` | `fischuu/hrp_humann:0.1` | HUMAnN |
| `krona` | `fischuu/hrp_krona:0.1` | Krona |
| `phyloflash` | `fischuu/hrp_phyloflash:0.2` | phyloFlash |
| `sylph` | `fischuu/sylph:0.8.1_0.1` | sylph |
| `r_report` | `fischuu/r-gbs:4.2.1-0.7` | The summaries of DIAMOND |
| `report` | `rocker/verse:4.4.2` | The module reports |
| `tiara` | `quay.io/biocontainers/tiara:1.0.3` | Tiara |
| `4cac` | `metagenlab/4cac:1.0` | 4CAC |
| `remag` | `quay.io/biocontainers/remag:0.5.1--pyhdfd78af_0` | REMAG |

## Versions of the tools in the containers {#sec-tool-versions}

Each tool runs in a container, so its version is fixed by the image in `config/.docker.yml`. This table comes from the images themselves. `book/tools/container_versions.sh` reads the installed packages of each image into `book/examples/container_versions.tsv`, and `book/tools/versions_table.py` writes the table here. If you change an image, run both of them again.

<!-- versions table: start -->
| Tool | Version | Image | Used in |
|-------------------|--------|--------------------------------|----------------------|
| FastQC | 0.12.1 | `fischuu/hrp_helpers:0.1` | All FastQC reports |
| fastp | 0.23.4 | `fischuu/hrp_preprocess:0.8` | `preprocess` |
| Bowtie2 | 2.5.1 | `fischuu/hrp_bowtie2:0.1` | `preprocess`, `quantify` |
| Bowtie2 | 2.5.1 | `fischuu/hrp_assemble:0.2` | `assemble` |
| SAMtools | 1.18 | `fischuu/hrp_bowtie2:0.1` | `preprocess`, `quantify` |
| SAMtools | 1.18 | `fischuu/hrp_assemble:0.2` | `assemble`, `contig_annotate` |
| SAMtools | 1.18 | `fischuu/hrp_helpers:0.1` | The generic rules |
| SAMtools | 1.20 | `fischuu/hrp_concoct:0.1` | `assemble__concoct__run` |
| Kraken2 | 2.1.3 | `fischuu/hrp_preprocess:0.8` | `read_annotate` |
| Krona | 2.8.1 | `fischuu/hrp_krona:0.1` | `read_annotate` |
| SingleM | 0.18.0 | `fischuu/hrp_preprocess:0.8` | `read_annotate` |
| sylph | 0.8.1 | `fischuu/sylph:0.8.1_0.1` | `read_annotate` |
| MetaPhlAn | 4.1.1 | `fischuu/hrp_preprocess:0.8` | `read_annotate` |
| HUMAnN | 3.9 | `fischuu/hrp_humann:0.1` | `read_annotate` |
| phyloFlash | 3.4.2 | `fischuu/hrp_phyloflash:0.2` | `read_annotate` |
| DIAMOND | 2.1.8 | `fischuu/hrp_annotate:0.4` | `read_annotate`, `contig_annotate` |
| Nonpareil | 3.4.1 | `fischuu/hrp_preprocess:0.8` | `read_annotate` |
| MEGAHIT | 1.2.9 | `fischuu/hrp_assemble:0.2` | `assemble` |
| SPAdes (metaSPAdes) | 3.15.5 | `fischuu/hrp_assemble:0.2` | `assemble` |
| CONCOCT | 1.1.0 | `fischuu/hrp_concoct:0.1` | `assemble` |
| MaxBin2 | 2.2.7 | `fischuu/hrp_assemble:0.2` | `assemble` |
| MetaBAT2 | 2.15 | `fischuu/hrp_assemble:0.2` | `assemble` |
| Prodigal | 2.6.3 | `fischuu/hrp_assemble:0.2` | `assemble`, `contig_annotate` |
| HMMER | 3.3.2 | `fischuu/hrp_assemble:0.2` | `assemble`, `contig_annotate` |
| dRep | 3.4.3 | `fischuu/hrp_assemble:0.2` | `assemble` |
| CheckM | 1.2.2 | `fischuu/hrp_assemble:0.2` | Inside dRep |
| CoverM | 0.6.1 | `fischuu/hrp_quantify:0.2` | `quantify` |
| featureCounts (Subread) | 2.0.1 | `fischuu/subread:2.0.1-0.1` | `contig_annotate` |
| QUAST | 5.2.0 | `fischuu/hrp_annotate:0.4` | `mag_annotate` |
| CheckM2 | 1.0.2 | `fischuu/hrp_checkm2:0.1` | `mag_annotate` |
| GTDB-Tk | 2.4.0 | `fischuu/hrp_gtdbtk:0.3` | `mag_annotate` |
| PhyloPhlAn | 3.1.1 | `fischuu/hrp_annotate:0.4` | `mag_annotate` |
| DRAM | 1.5.0 | `fischuu/hrp_dram:0.4` | `mag_annotate` |
| CAMPER | 1.0.13 | `fischuu/hrp_camper:0.1` | `mag_annotate`, `contig_annotate` |
| Bakta | 1.9.3 | `fischuu/hrp_annotate:0.4` | `mag_annotate` |
| eggNOG-mapper | 2.1.12 | `fischuu/hrp_eggnog:0.1` | `mag_annotate__eggnog` |
| eggNOG-mapper | 2.1.12 | `fischuu/hrp_annotate:0.4` | `contig_annotate` |
| Proteinortho | 6.3.1 | `fischuu/hrp_annotate:0.4` | `mag_annotate` |
| Tiara | 1.0.3 | `quay.io/biocontainers/tiara:1.0.3` | `eukaryote` |
| REMAG | 0.5.1 | `quay.io/biocontainers/remag:0.5.1--pyhdfd78af_0` | `eukaryote` |
<!-- versions table: end -->

Some tools exist in more than one image with different versions, which is why the table names the image. For example, the Bowtie2 that removes host reads is another installation than the one that maps reads to the assemblies, even though they have the same version here. `hrp_preprocess:0.8` holds Bowtie2 2.5.4, DIAMOND 2.1.10 and HMMER 3.2.1, but the rules that use those tools run in other images.

The MAGScoT script and `NCycProfiler.PL` aren't in an image. They come with the pipeline, in `workflow/scripts/`. 4CAC has no package in its image, and its version is the tag of the image, 1.0.
