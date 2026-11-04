# DRAM {#sec-tool-dram}

## What it does

DRAM (Distilled and Refined Annotation of Metabolism) annotates genomes with a focus on metabolism. It finds out what each gene is and then it "distills" this into an overview of what a genome can do: for example, which carbohydrates it can use, and whether it can make methane.

## How it works

**Annotate.** DRAM takes the contigs, predicts genes with Prodigal, and compares them with many databases: Pfam, dbCAN for carbohydrate-active enzymes, MEROPS for peptidases, VOGDB for viruses, UniRef90, and optionally KEGG, which needs a licence. KOfam is used in its place in this pipeline. It also finds tRNA genes with tRNAscan-SE, and rRNA genes with barrnap.

**Distill.** It then uses hand-curated tables to turn the annotation into a list of metabolic functions, and it summarizes them per genome.

## Input

| Step | Input |
|------|-------|
| `DRAM.py annotate` | FASTA with contigs. Each file counts as one genome. Optionally a taxonomy from GTDB-Tk |
| `DRAM.py distill` | The tables from the annotation step |
| Both | A config file that tells where the databases are |

## Output

| File | Step | Content |
|------|------|---------|
| `annotations.tsv` | annotate | One line per gene, with all database hits |
| `genes.faa`, `genes.fna`, `genes.gff` | annotate | Genes as proteins, as DNA and as positions |
| `trnas.tsv`, `rrnas.tsv` | annotate | tRNA and rRNA genes |
| `genome_stats.tsv` | distill | Quality per genome, including the checks for rRNA and tRNA |
| `metabolism_summary.xlsx` | distill | A workbook with one sheet per group of functions |
| `product.html`, `product.tsv` | distill | A heatmap of functions per genome, and its data |

`product.html` is what to look at first. `metabolism_summary.xlsx` is the place for details.

## When to use it

Use it to get an overview of the metabolism of a set of MAGs, in particular for carbon and energy metabolism. It's a heavy tool: the databases take hundreds of GB and it needs much memory. If you only need a general annotation, Bakta or eggNOG-mapper is lighter.

## In this pipeline

Each of the two runs has three steps. `mag_annotate__dram__annotate`, `mag_annotate__fix_dram_annotations_scaffold` and `mag_annotate__dram__distill` run on the catalogue. `mag_annotate__dram_mag__annotate`, `mag_annotate__fix_dram_mag_annotations_scaffold` and `mag_annotate__dram_mag__distill` run on the binned contigs of each assembly.

**Note what happens to genome names.** DRAM treats one FASTA file as one genome, but the catalogue is a single file with all MAGs. So DRAM would see one huge genome. The repair step, `workflow/scripts/fix_annotations.py`, writes the part of the contig name before the `@` into the column for the scaffold. So the distillation can tell the MAGs apart, and that's why the contig names matter here as well.

`config/dram_config.txt` holds the paths to the databases, all relative to the project folder. `kegg` is `null`, so KEGG isn't used.

## Pitfalls

- **Temporary files.** DRAM starts tRNAscan-SE, which reads `$TMPDIR`, and on the cluster the inherited value points to a place that the container can't see. Without the rule's fix, DRAM would crash in this step. The comment in the rule explains this.
- **Empty tables.** If there's no tRNA, DRAM writes no table. The rule then leaves an empty file, as the next step needs one.
- **Paths in the config.** All database paths have to exist from the project folder. If you keep the databases elsewhere, you have to change this file.

## Reference

Shaffer M, et al. (2020). DRAM for distilling microbial metabolism to automate the curation of microbiome function. *Nucleic Acids Research*. <https://doi.org/10.1093/nar/gkaa621>

# CAMPER {#sec-tool-camper}

## What it does

CAMPER (Curated Annotations for Microbial Polyphenol Enzymes and Reactions) looks for genes that break down or modify polyphenols. Polyphenols are plant compounds such as tannins. For a long time, it was assumed that they weren't metabolized in low-oxygen environments, but studies have since shown that microbes do act on them. In a rumen, feed tannins are an important topic in their own right.

General annotation tools hardly cover these functions. That's why this special database exists.

## How it works

It has two sets of references: protein sequences with score cutoffs for a DIAMOND search, and protein profiles for an HMMER search, each with cutoffs by hand. It searches with both, and then it writes a summary, called distillate.

## Input

Protein sequences (`-i`), and the paths to the files of the database.

## Output

| File | Content |
|------|---------|
| `annotations.tsv` | One line per gene with hits |
| `distillate.tsv` | The summary |

## When to use it

Use it when polyphenols are part of your question, as a supplement to a general annotation.

## In this pipeline

It runs twice, and both runs use the same commands:

| Rule | Proteins from |
|------|---------------|
| `mag_annotate__camper__annotate` | DRAM, on the catalogue |
| `contig_annotate__camper__annotate` | Prodigal, on all contigs of each assembly |

The rules copy the database first, to `nvme_storage`, and they run in a temporary folder that has to not exist yet. This is the strange step `mkdir -p`, then `rm -rf`, which a comment in the rule calls "a strange camper requirement".

## Pitfalls

- **Without a local disk.** The rule falls back to a folder in the results if `nvme_storage` is empty.
- **A shared folder for the database copy.** In `mag_annotate__camper__annotate`, the database goes straight into `nvme_storage`, without a subfolder for the job. If a local disk is shared with other jobs, they could interfere.

## Reference

McGivern BB, et al. (2024). Microbial polyphenol metabolism is part of the thawing permafrost carbon cycle. *Nature Microbiology*. <https://doi.org/10.1038/s41564-024-01691-0>

# Bakta {#sec-tool-bakta}

## What it does

Bakta annotates bacterial genomes in a standardized way, and it writes the files needed for submission to the public databases. It finds genes of all kinds, and it gives them consistent names, with links to other databases.

## How it works

1. It finds non-coding features: tRNA, tmRNA, rRNA, ncRNA and others. It also finds CRISPR arrays if you want them.
2. It predicts coding genes with Pyrodigal, a Python version of Prodigal.
3. To name them, it computes a hash of each protein, and looks it up in a large table of known proteins. An exact match is found immediately, without any alignment. Only the rest go to DIAMOND. This makes it fast.

## Input

FASTA with contigs, and a database (`--db`), which comes in a full and a smaller form.

## Output

All files share the prefix from `--prefix`:

| File | Content |
|------|---------|
| `.tsv` | The annotation as a table, one line per feature |
| `.gff3`, `.gbff`, `.embl` | The annotation in the standard formats |
| `.faa`, `.ffn`, `.fna` | Proteins, genes and contigs |
| `.hypotheticals.tsv` | Details on proteins without a known function |
| `.txt`, `.json` | Summary and full data |

## When to use it

Use it for single, reasonably complete genomes, when you want a standard annotation. It's also useful if you want to submit genomes. It's meant for Bacteria, and for genomes rather than whole metagenomes.

## In this pipeline

| Rule | Input |
|------|-------|
| `mag_annotate__bakta` | The whole catalogue, as one input |
| `mag_annotate__bakta_mags__run` | The binned contigs of each assembly |

So it doesn't run per genome. The catalogue looks like one large genome to Bakta. Its results are still annotated by contig, so you can split them up by the contig names. `--skip-crispr --skip-plot` comes from `params.yaml`. Note that Bakta also has an option `--meta`, which lets the gene prediction expect a mixture. This pipeline doesn't use it by default, and you could add it to `additional_options`.

The proteins from `mag_annotate__bakta_mags__run` are the input for Proteinortho.

As in DRAM, the rule sets its own `TMPDIR`, because of tRNAscan-SE. The comment explains why.

## Pitfalls

- **Many contigs.** Bakta is meant for genomes, and on a large assembly, it takes a long time.
- **Database version.** The database has to fit the version of the tool.
- **`--force`** overwrites the output folder, which is what the rules want here. Keep this in mind if you run it by hand.

## Reference

Schwengers O, et al. (2021). Bakta: rapid and standardized annotation of bacterial genomes via alignment-free sequence identification. *Microbial Genomics*. <https://doi.org/10.1099/mgen.0.000685>

# eggNOG-mapper {#sec-tool-eggnog}

## What it does

eggNOG-mapper gives genes a functional annotation, based on groups of orthologs: genes in different organisms that come from one gene in a common ancestor. Orthologs tend to keep their function, so that the function of one known member can be transferred to the others. This tends to be more precise than transferring it from any similar sequence.

## How it works

It has two steps, and you can run them separately:

1. **Search.** It compares your proteins with the eggNOG database, using DIAMOND or another search tool. For each protein, it finds the best match, the seed ortholog.
2. **Annotate.** It looks up the seed in the eggNOG database, finds its orthologs, and it transfers their annotation.

The first step is CPU-heavy, and it benefits from many threads. The second one reads a large SQLite database a lot, so it benefits from a fast disk or from memory (`--dbmem`).

## Input

| Option | Content |
|--------|---------|
| `-i` | Sequences. `--itype` says which: `proteins`, `CDS`, `genome`, `metagenome` |
| `--genepred` | How to find genes in the last two: `search` or `prodigal` |
| `--annotate_hits_table` | For the second step, the results of the first |
| `--data_dir` | The database folder |
| `-m` | The search tool, here `diamond` |

## Output

All files share the prefix from `-o`:

| File | Content |
|------|---------|
| `.emapper.seed_orthologs` | The results of the search |
| `.emapper.hits` | All hits |
| `.emapper.annotations` | The annotation |

The columns of the annotation include:

| Column | Content |
|--------|---------|
| `query` | Your gene |
| `seed_ortholog`, `evalue`, `score` | The best match |
| `eggNOG_OGs` | The groups of orthologs |
| `COG_category` | The broad functional class |
| `Description`, `Preferred_name` | What it is |
| `GOs`, `EC`, `KEGG_ko`, `KEGG_Pathway`, `KEGG_Module`, `CAZy`, `PFAMs` | Links to other systems |

The KEGG columns are often the most useful, as they let you map genes onto pathways.

## When to use it

Use it to annotate many genes at once, in a form you can summarize by categories. It's a good general choice for all contigs of an assembly.

## In this pipeline

It's used in two ways, and these differ.

**On all contigs**, as @sec-module-contig-annotate shows, it does both steps, on chunks of proteins from Prodigal: `contig_annotate__eggnog_find_homology` searches, and `contig_annotate__eggnog_orthology_chunk` annotates. `contig_annotate__eggnog_merge_annotations` joins the results.

**On the catalogue**, the rule `mag_annotate__eggnog` runs one call with `--itype metagenome --genepred prodigal`, and with `--no_annot`. So this call only performs the search, and the result is in `.emapper.seed_orthologs`. No annotation is written, and you would have to run the second step by hand with `--annotate_hits_table`.

### eggNOG version 7

The rule `contig_annotate__eggnog7__run` uses a newer annotator for version 7 of the database, through `workflow/scripts/eggnog7_annotator.sh`. This script is simpler: it searches a DIAMOND database (`_proteins.dmnd`) with an E-value of `1e-5`, and it looks up the hits in a table (`_master_search_table.tsv.gz`). The result is `{assembly_id}.eggnog.tsv.gz`. Note that it's a separate, newer data set, so the results don't exactly match the classic one.

## Pitfalls

- **Comment lines.** `--no_file_comments` removes the headers that start with `##`. That's useful when you concatenate chunks.
- **Mixing versions.** The results from a certain database version shouldn't be mixed with those from another.
- **Only the best match.** A distant seed gets an annotation just like a close one. Filter by `evalue` and `score` if needed.

## Reference

Cantalapiedra CP, Hernández-Plaza A, Letunic I, Bork P, Huerta-Cepas J (2021). eggNOG-mapper v2: Functional Annotation, Orthology Assignments, and Domain Prediction at the Metagenomic Scale. *Molecular Biology and Evolution*. <https://doi.org/10.1093/molbev/msab293>

# Proteinortho {#sec-tool-proteinortho}

## What it does

Proteinortho finds orthologs between several sets of proteins. So it tells you which genes different genomes or assemblies have in common, and which are unique to some of them.

## How it works

It compares all proteins with each other, set against set, with DIAMOND by default. It keeps reciprocal best hits: pairs of proteins that are each other's best match. These form a graph, and a clustering step splits it into groups of orthologs.

## Input

Two or more protein FASTA files, one per species or genome.

## Output

All files share the prefix from `-project`:

| File | Content |
|------|---------|
| `.proteinortho.tsv` | The main table |
| `.proteinortho.html` | The same for a browser |
| `.blast-graph`, `.proteinortho-graph` | The graphs |

The main table has one line per group of orthologs, with these columns:

| Column | Content |
|--------|---------|
| `# Species` | How many sets are in this group |
| `Genes` | How many genes are in it |
| `Alg.-Conn.` | How well the group is connected, 1 being best |
| One per input | The genes of this set, or `*` if there's none |

## When to use it

Use it for comparing the gene content of several genomes, to find a core and an accessory part. It works for hundreds of genomes.

## In this pipeline

The rule `mag_annotate__proteinortho` compares the proteins from Bakta's run on each assembly:

```bash
proteinortho {input.faa} -cpus={threads} -project=proteinortho
mv proteinortho.* {params.outdir}
```

Note what the sets are: **each set is one assembly, not one genome**. So the table shows what's shared between assemblies. To compare genomes, you'd have to split the proteins by genome first.

The rule needs at least two assemblies, so with a single assembly, it fails.

## Reference

Lechner M, et al. (2011). Proteinortho: Detection of (Co-)orthologs in large-scale analysis. *BMC Bioinformatics*. <https://doi.org/10.1186/1471-2105-12-124>
