# Prodigal {#sec-tool-prodigal}

## What it does

Prodigal finds protein-coding genes in the DNA of Bacteria and Archaea. It takes a sequence, and it reports where genes lie and which proteins they code for. Nearly all annotation in this pipeline starts from its output.

## How it works

A gene of a prokaryote is a long open reading frame, without a stop codon, and it has a typical pattern of codons. Prodigal looks at all possible open reading frames, and it scores them by things such as the use of codons, the start codon and the site where the ribosome binds. Then it chooses the best-scoring set of genes that fit together.

Normally, it learns these patterns from the genome itself, in a training step. A contig from a metagenome is too short for that, and it comes from an unknown organism. So in **meta mode** (`-p meta`), Prodigal uses a set of precomputed models, and for each sequence it picks the model that fits best.

## Input

FASTA with nucleotide sequences (`-i`, or the standard input).

## Output

| Option | Content |
|--------|---------|
| `-a` | Protein sequences |
| `-d` | Nucleotide sequences of the genes |
| `-o` | Positions, in the format from `-f`, such as `gff` or `gbk` |

A protein is named after its contig plus a number, as in `contig_1_3` for the third gene on `contig_1`. Several tools rely on this. MAGScoT, for example, finds the contig by removing the last number. The header of each protein holds its start, its end, its strand and details such as:

| Field | Meaning |
|-------|---------|
| `partial` | `00` for a complete gene. A 1 means that it runs off the start or the end of the contig |
| `start_type` | The start codon |
| `rbs_motif` | The binding site of the ribosome |
| `gc_cont` | GC content |

## When to use it

Use it for Bacteria and Archaea. It's fast, and it's accurate for them.

Don't use it for eukaryotes, as it doesn't handle introns. Be careful with organisms that use another genetic code, too. Prodigal assumes code 11 unless told otherwise, and some groups, such as Mycoplasma and CPR bacteria, use other ones. In meta mode, it has models for this.

Since eukaryotic contigs get wrong gene calls, a eukaryote-rich sample needs other tools, such as those of @sec-module-eukaryote, before you interpret these results.

## In this pipeline

It runs in two places, always in meta mode:

| Rule | On | Why |
|------|----|-----|
| `assemble__magscot__prodigal` | Contigs of each assembly | For finding marker genes |
| `contig_annotate__prodigal__run` | Contigs of each assembly | For annotation and counting |

The first uses `parallel`, as Prodigal only has a single thread, and it needs just the proteins. The second writes proteins and positions, and it runs on a single thread. So the same genes are predicted twice, for these different purposes.

Bakta, DRAM and eggNOG-mapper each run their own gene prediction, which also uses Prodigal.

## Pitfalls

- **Single-threaded.** A large assembly takes hours. `parallel` is a good way to speed it up, as long as you keep the order.
- **Partial genes.** On contigs, many genes are cut off at the edge. It's normal, and they count as genes.
- **A protein ending in `*`.** Prodigal marks stop codons with an asterisk at the end of the protein. Some tools don't accept it.

## Reference

Hyatt D, et al. (2010). Prodigal: prokaryotic gene recognition and translation initiation site identification. *BMC Bioinformatics*. <https://doi.org/10.1186/1471-2105-11-119>

# HMMER {#sec-tool-hmmer}

## What it does

HMMER searches protein sequences using profile hidden Markov models. A profile doesn't describe one sequence, but a whole family: which positions are conserved, which vary and where gaps are common. So it finds distant family members that a comparison with a single sequence would miss.

## How it works

A profile is built from an alignment of a protein family. It holds, for each position, how likely each amino acid is, and how likely an insertion or a deletion is. HMMER then computes how well a protein fits this model, and it does it fast by using a series of filters that throw out hopeless candidates early.

The result is a score in bits, and an E-value: how many such hits you'd expect by chance in a search of this size. Many profile collections come with thresholds for each family, called gathering (GA), noise (NC) and trusted (TC) cutoffs. `--cut_nc` uses the noise cutoff, which is what MAGScoT asks for here.

## Input

`hmmsearch` takes a file of profiles and a file of protein sequences. It searches each profile against all the sequences. The profiles come from a database such as Pfam or TIGRFAM, or you can build them from your own alignment with `hmmbuild`.

## Output

| Option | Content |
|--------|---------|
| `-o` | The human-readable report |
| `-A` | An alignment of the hits |
| `--tblout` | A table with one line per protein and profile |
| `--domtblout` | A table with one line per domain |
| `--pfamtblout` | A compact table for Pfam |

The columns of `--tblout` are separated by spaces, and they start like this:

| Column | Content |
|--------|---------|
| 1, 2 | Name and accession of the protein |
| 3, 4 | Name and accession of the profile |
| 5, 6, 7 | E-value, score and bias of the whole sequence |

Lines that start with `#` are comments.

## When to use it

Use it when you search for a certain protein family, and particularly for families with a good curated profile. It's the standard for marker genes. It's more sensitive than DIAMOND for distant members, and it's slower. So for comparing with very large collections, you'd use DIAMOND.

## In this pipeline

| Rule | Profiles | Question |
|------|----------|----------|
| `assemble__magscot__hmmsearch` | The marker genes of GTDB | Which bins are complete? |
| `contig_annotate__hmmer__assign` | The hydrogenases of HydDB | Which genes are hydrogenases? |

In the second rule, `--domT` sets a minimum score per domain, a separate value per database, as @sec-module-contig-annotate shows. This option only filters the domains: `--tblout` still reports sequences with a lower score, down to an E-value of 10.

## Pitfalls

- **Whitespace in the tables.** Columns are padded with spaces, not tabs. Read them with `awk`, as the pipeline does.
- **Which accession?** Pfam and TIGRFAM don't fill the same columns with the name of the marker. For this reason, `assemble__magscot__marker_table` uses column 3 for one and column 4 for the other.
- **E-value and database size.** The E-value grows with the number of sequences you search. Scores don't, which is why fixed score thresholds are a good choice.

## Reference

Eddy SR (2011). Accelerated Profile HMM Searches. *PLoS Computational Biology*. <https://doi.org/10.1371/journal.pcbi.1002195>
