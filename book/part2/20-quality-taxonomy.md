# QUAST {#sec-tool-quast}

## What it does

QUAST evaluates assemblies. Without a reference, it reports length statistics, and with a reference, it can also find misassemblies. It's a quick way of getting the numbers everyone asks about.

## Understanding the numbers

| Value | Meaning |
|-------|---------|
| `# contigs` | How many sequences, usually counted from a length of 500 bases |
| `Largest contig` | The longest |
| `Total length` | The sum of all lengths |
| `N50` | Half of all bases are in contigs of at least this length. Larger is better |
| `L50` | How many contigs make up that half. Smaller is better |
| `GC (%)` | The GC content |

N50 is a measure of how fragmented the assembly is, and it's the most quoted number. Be aware that it says nothing about whether the contigs are correct, and that it can be raised by simply dropping short contigs.

## Input

FASTA files with the assemblies. A reference is optional (`-r`). `metaquast.py` is a version for metagenomes that can work with several references.

## Output

| File in the output folder | Content |
|------|---------|
| `report.txt`, `report.tsv` | The table of numbers |
| `transposed_report.tsv` | The same, with one line per assembly, for many assemblies |
| `report.html` | The report for a browser |
| `icarus.html` | An interactive view of contigs |
| `quast.log` | The log |

## When to use it

Use it for comparing assemblies or assemblers on the same data. Don't compare the N50 between very different samples, as it depends on the complexity of the community and on the depth.

## In this pipeline

The rule `mag_annotate__quast` runs it on the catalogue, as one file:

```bash
quast -o {output} -t {threads} {input}
```

So the numbers describe the set of contigs in the catalogue as a whole, and not each genome. The value of `# contigs` isn't per genome, and N50 is over all genomes. It doesn't evaluate the individual assemblies. To do that, run it by hand on `results/assemble/<assembler>/*.fa.gz`. For the quality of single genomes, CheckM2 is the right tool, and its table also gives an N50 per genome.

## On real data

@sec-tutorial-mag-annotate shows real output of this tool, and how to read it.

## Reference

Gurevich A, Saveliev V, Vyahhi N, Tesler G (2013). QUAST: quality assessment tool for genome assemblies. *Bioinformatics*. <https://doi.org/10.1093/bioinformatics/btt086>

# CheckM2 {#sec-tool-checkm2}

## What it does

CheckM2 estimates the completeness and the contamination of a genome. This is the most important check of a MAG. Everything else you say about a genome rests on it.

## How it works

The original CheckM counted marker genes specific to a lineage. That doesn't work well for groups without good reference genomes, or for those with reduced genomes.

CheckM2 uses machine learning. It predicts the genes of a genome, and it compares them with a database with DIAMOND. The presence and absence of many gene families and the amino acid composition go into two models, trained on genomes that were artificially thinned out and mixed: a general gradient-boosting model and a neural network. It picks which to trust depending on how close the genome is to its training data. This works without first placing the genome in a tree.

## Input

A folder or list of genomes (`-i`) in FASTA, with their file ending (`-x`), and the database (`--database_path`).

## Output

`quality_report.tsv`, with one line per genome:

| Column | Content |
|--------|---------|
| `Name` | The genome |
| `Completeness` | Estimated percentage |
| `Contamination` | Estimated percentage |
| `Completeness_Model_Used` | Which model was used |
| `Translation_Table_Used` | The genetic code |
| `Coding_Density` | Share that codes for proteins |
| `Contig_N50`, `Average_Gene_Length`, `Genome_Size`, `GC_Content`, `Total_Coded_Sequences` | Statistics |
| `Additional_Notes` | Warnings, if any |

## What's a good genome?

A widely used standard is MIMAG (Bowers et al. 2017):

| Quality | Completeness | Contamination | Also needs |
|---------|-------------|---------------|-----------|
| High | Over 90% | Below 5% | rRNA genes (23S, 16S, 5S) and at least 18 tRNAs |
| Medium | At least 50% | Below 10% | |
| Low | Below 50% | Below 10% | |

Note the additional demand for rRNA genes. Short-read assemblies seldom get these, so many MAGs that reach the numbers aren't "high quality" by the strict definition. DRAM reports rRNA and tRNA genes per genome, so you can check.

## When to use it

Use it on every MAG you want to use. It doesn't work for eukaryotes or viruses, for which you need EukCC or BUSCO, and CheckV.

## In this pipeline

The rule `mag_annotate__checkm2__predict` runs it on the dereplicated genomes. The result is at `results/mag_annotate/checkm2/quality_report.tsv`.

dRep uses the older CheckM for its filter, as @sec-tool-drep explains, so you can see two sets of values for a genome. Use CheckM2's for your report.

## On real data

This book has no real output of this tool yet. @sec-tutorial-waiting says why, and it will come from a complete run on a cluster.

## Pitfalls

- **Numbers are estimates.** They aren't exact, and a MAG with very low estimated contamination can still have a wrong contig.
- **Completeness isn't correctness.** Chimeric bins with parts of relatives can look fine.
- **File ending.** `-x` must match exactly, here `.fa.gz`. If not, CheckM2 finds no genomes.

## References

Chklovski A, Parks DH, Woodcroft BJ, Tyson GW (2023). CheckM2: a rapid, scalable and accurate tool for assessing microbial genome quality using machine learning. *Nature Methods*. <https://doi.org/10.1038/s41592-023-01940-w>

Bowers RM, et al. (2017). Minimum information about a single amplified genome (MISAG) and a metagenome-assembled genome (MIMAG) of bacteria and archaea. *Nature Biotechnology*. <https://doi.org/10.1038/nbt.3893>

# GTDB-Tk {#sec-tool-gtdbtk}

## What it does

GTDB-Tk assigns a taxonomy to genomes of Bacteria and Archaea, based on the Genome Taxonomy Database (GTDB). It tells you where a MAG belongs in the tree of life, and also whether it's a known species.

## What's GTDB?

GTDB is a taxonomy built directly from genome phylogeny, with ranks defined by a consistent measure. So it differs from the NCBI taxonomy in many places, and names may change. For example, Firmicutes is now split up and called Bacillota in several parts. Remember this when you compare with older literature.

## How it works

The workflow `classify_wf` runs three steps.

1. **identify.** It finds 120 bacterial and 53 archaeal marker genes in each genome, with Prodigal and HMMER.
2. **align.** It aligns these markers, and it concatenates them into one long sequence per genome.
3. **classify.** It places each genome in a reference tree, with pplacer. It uses the position in the tree and the relative evolutionary divergence (RED) to decide the rank. Then it compares it with close reference genomes, by ANI, to decide on the species.

## Input

A folder of genomes (`--genome_dir`), with their ending (`-x`), and the database, through the environment variable `GTDBTK_DATA_PATH`. The version of the tool and the release of the database must fit each other.

## Output

| File | Content |
|------|---------|
| `gtdbtk.bac120.summary.tsv` | Results for Bacteria |
| `gtdbtk.ar53.summary.tsv` | Results for Archaea, if there are any |
| `classify/`, `align/`, `identify/` | Intermediate results and trees |
| `gtdbtk.warnings.log` | Genomes with problems |

The most useful columns are:

| Column | Content |
|--------|---------|
| `user_genome` | Your genome |
| `classification` | The taxonomy, as `d__Bacteria;p__...;c__...;o__...;f__...;g__...;s__...` |
| `classification_method` | How it was decided |
| `note` | Remarks, for example on ANI |
| `msa_percent` | Share of the alignment that's filled |
| `warnings` | Warnings |

An empty name at a rank, such as a line ending in `s__`, says that no known species fits at that rank. **So your MAG may represent a new species or genus**, and that's one of the exciting results in a less-known habitat like the rumen.

## When to use it

Use it for any MAG of Bacteria or Archaea. It needs a large database and quite some memory, but only once per genome set.

Low-quality MAGs have too few markers. So they can get a poor placement, and you see this in `msa_percent`.

## In this pipeline

The rule `mag_annotate__gtdbtk__classify` runs it on the dereplicated genomes, with the database from `features.yaml`, by default release 220:

```bash
GTDBTK_DATA_PATH={input.reference_data} gtdbtk classify_wf \
    --genome_dir {input.genomes} -x fa.gz --out_dir {GTDBTK} --cpus {threads} --skip_ani_screen
```

`--skip_ani_screen` skips the first quick comparison, which would need one more database. It joins the two tables into `gtdbtk.summary.tsv`, and packs the folders with intermediate results into archives. DRAM uses the table.

## On real data

This book has no real output of this tool yet. @sec-tutorial-waiting says why, and it will come from a complete run on a cluster.

## Pitfalls

- **Memory.** It can use a lot, and the amount depends on the database release. This rule runs in the resource set `large`.
- **The version and the release.** A tool of one version doesn't work with a database of another.
- **`--skip_ani_screen`.** Genomes are placed through the tree, not by a first ANI screen. This costs time, but it doesn't change much of the result.
- **Taxonomy names in the literature.** Compare carefully, as the names differ from NCBI's.

## References

Chaumeil PA, Mussig AJ, Hugenholtz P, Parks DH (2022). GTDB-Tk v2: memory friendly classification with the genome taxonomy database. *Bioinformatics*. <https://doi.org/10.1093/bioinformatics/btac672>

Parks DH, et al. (2022). GTDB: an ongoing census of bacterial and archaeal diversity through a phylogenetically consistent, rank normalized and complete genome-based taxonomy. *Nucleic Acids Research*. <https://doi.org/10.1093/nar/gkab776>

# PhyloPhlAn {#sec-tool-phylophlan}

## What it does

PhyloPhlAn is a set of tools for phylogenetics of microbial genomes. The pipeline uses one of them, `phylophlan_assign_sgbs`. It assigns each MAG to a species-level genome bin (SGB) from a large collection, which holds both known species and species that are known only from metagenomes.

So you learn whether a MAG belongs to a group that has been seen before in other studies, even if nobody has given it a name.

## How it works

It sketches each genome with Mash, and it compares this with the sketches of all SGBs. Each SGB stands for a species-level cluster, with genomes that have at least 95% ANI to each other. It reports the closest SGBs, with a distance. A label shows if it's a known species (kSGB) or one without a named species (uSGB).

## Input

A folder of genomes (`-i`), their ending (`-e`), a database name (`-d`) and folder (`--database_folder`).

## Output

A table (`-o`, written as `<o>.tsv`), with one line per genome, and with the closest SGBs and their distances.

## When to use it

Use it as a companion to GTDB-Tk. The names don't follow GTDB, and the SGB collection ties in with the MetaPhlAn world, which makes it easy to compare with studies that use it.

For building a real phylogenetic tree of your genomes, the main `phylophlan` program is what you want. This pipeline doesn't run that.

## In this pipeline

The rule `mag_annotate__phylophlan` runs it on the dereplicated genomes:

```bash
phylophlan_assign_sgbs -i {input} \
                       -d SGB.Jun23 \
                       --database_folder resources/databases/phylophlan/ \
                       -e fa.gz -o {params.result} \
                       --nproc {threads} --verbose --overwrite
```

As the comment in the rule says, the database name and folder are written into the rule. The list under `phylophlan` in `features.yaml` has no effect on it, nor do `phylophlan-config` in `config.yaml` and `diversity` in `params.yaml`.

## On real data

This book has no real output of this tool yet. @sec-tutorial-waiting says why, and it will come from a complete run on a cluster.

## Reference

Asnicar F, et al. (2020). Precise phylogenetic analysis of microbial isolates and genomes from metagenomes using PhyloPhlAn 3.0. *Nature Communications*. <https://doi.org/10.1038/s41467-020-16366-7>
