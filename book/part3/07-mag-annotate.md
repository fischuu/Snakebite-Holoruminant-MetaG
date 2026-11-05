# Module `mag_annotate` {#sec-module-mag-annotate}

The catalogue from @sec-module-assemble is a set of DNA sequences. This module finds out what they are: how good each genome is, which organism it comes from, and what it can do.

```bash
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate

# Or a single tool:
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__checkm2
```

## The tools at a glance

| Target | Tool | Answers | Works on |
|--------|------|---------|----------|
| `mag_annotate__quast` | @sec-tool-quast | How long and how fragmented are the sequences? | Catalogue |
| `mag_annotate__checkm2` | @sec-tool-checkm2 | How complete and how contaminated is each genome? | Each genome |
| `mag_annotate__gtdbtk` | @sec-tool-gtdbtk | Which organism is it? | Each genome |
| `mag_annotate__phylophlan` | @sec-tool-phylophlan | Which known species-level group does it belong to? | Each genome |
| `mag_annotate__dram` | @sec-tool-dram | What can the genomes do, in metabolism? | Catalogue |
| `mag_annotate__dram_mags` | @sec-tool-dram | The same per assembly | Binned contigs |
| `mag_annotate__camper` | @sec-tool-camper | Which polyphenol-related genes? | DRAM's genes |
| `mag_annotate__bakta` | @sec-tool-bakta | Standardized gene annotation | Catalogue |
| `mag_annotate__bakta_mags` | @sec-tool-bakta | The same per assembly | Binned contigs |
| `mag_annotate__eggnog` | @sec-tool-eggnog | Which orthologous groups do the genes belong to? | Catalogue |
| `mag_annotate__proteinortho` | @sec-tool-proteinortho | Which genes are shared between assemblies? | Bakta's proteins |

Notice the order they depend on each other. DRAM reads the taxonomy from GTDB-Tk, CAMPER reads DRAM's genes, and Proteinortho reads Bakta's proteins. Snakemake takes care of this if you call a single tool.

All rules of this module share the path `results/mag_annotate/<tool>/`.

**Start with CheckM2.** Everything else says something about the genomes, but only CheckM2 tells you which genomes to trust.

## Quality

### `mag_annotate__quast`

```bash
quast -o {output} -t {threads} {input}
```

Note that the input is the whole catalogue as one file. So this gives numbers for the catalogue as a whole, and not per genome.

### `mag_annotate__checkm2__predict`

```bash
checkm2 predict -i {input.genomes} -x .fa.gz -o "$workdir" -t {threads} \
    --database_path {input.reference_data} --remove_intermediates
mv "$workdir/quality_report.tsv" {output}
```

This rule writes `quality_report.tsv`, with one line per genome. CheckM2 wants to make its own output folder, so the rule works in a temporary folder and moves the result. `mag_annotate__checkm2` is the target.

## Taxonomy

### `mag_annotate__gtdbtk__classify`

```bash
GTDBTK_DATA_PATH={input.reference_data} gtdbtk classify_wf \
    --genome_dir {input.genomes} -x fa.gz --out_dir {GTDBTK} --cpus {threads} --skip_ani_screen
```

GTDB-Tk needs a lot of memory, which is why this rule has the resource set `large`. Note the three points in the rule:

- `--skip_ani_screen` skips the first comparison against all reference genomes, which needs an additional database.
- GTDB-Tk treats Bacteria and Archaea separately, so it writes two tables. Only if there are archaea does the second exist. The rule joins them into `gtdbtk.summary.tsv`, or it copies the bacterial table if there's only one.
- The working folders `align`, `classify` and `identify` are packed into archives.

If a MAG can't be placed, GTDB-Tk reports it in the warnings. `mag_annotate__gtdbtk` is the target.

### `mag_annotate__phylophlan`

```bash
phylophlan_assign_sgbs -i {input} \
                       -d SGB.Jun23 \
                       --database_folder resources/databases/phylophlan/ \
                       -e fa.gz \
                       -o {params.result} \
                       --nproc {threads} \
                       --verbose \
                       --overwrite
```

This assigns each MAG to a species-level genome bin. Note what the comment in the rule says: the database name and folder are written into the rule, and don't come from `features.yaml`. The entries `amphora2` and `phylophlan` there aren't used by this rule. If you keep this database elsewhere, change the rule.

## Function

### DRAM on the catalogue

DRAM works in two steps, and between them one small repair.

`mag_annotate__dram__annotate` predicts genes and compares them with DRAM's databases:

```bash
DRAM.py annotate -i {input.catalogue} -o {_DRAM_TABLES} --threads {threads} \
    --gtdb_taxonomy {input.taxonomy} --config_loc {params.dram_config}
```

`--config_loc` points to `config/dram_config.txt`, which holds the paths of DRAM's databases. **Check these paths in your project**, as they are relative to the project folder.

DRAM skips a table if it finds nothing of that kind, for example no tRNAs. The rule then writes an empty file, as the next rules expect all three.

Like several tools in this module, DRAM starts other programs that use `$TMPDIR`, and on the cluster the inherited value points to a place that the container can't see. So the rule sets its own. The comments in the rules of Bakta and DRAM explain this.

`mag_annotate__fix_dram_annotations_scaffold` then repairs the annotation table with `workflow/scripts/fix_annotations.py`, so that the next step can read it.

`mag_annotate__dram__distill` summarizes the annotation, and writes `genome_stats.tsv`, `metabolism_summary.xlsx`, `product.html` and `product.tsv`. DRAM insists on making its own folder, so the rule works in a temporary one again. `mag_annotate__dram` is the target.

### DRAM per assembly

The same three steps, but on the binned contigs of each assembly and without the taxonomy: `mag_annotate__dram_mag__annotate`, `mag_annotate__fix_dram_mag_annotations_scaffold` and `mag_annotate__dram_mag__distill`. `mag_annotate__dram_mags` is the target. The results are in `results/mag_annotate/dram_mags/{assembly_id}/`.

Why both? The catalogue holds one genome per species over all samples. The per-assembly view keeps what each assembly found, also for genomes that were dropped by dRep.

### `mag_annotate__camper__annotate`

CAMPER looks for genes of the metabolism of polyphenols. It uses the genes from DRAM. The rule first copies the database to fast storage, and runs two steps:

```bash
camper_annotate -i {input.genes} -o $tmpdir --threads {threads} \
                --camper_fa_db_loc $tmp_db_dir/CAMPER_blast.faa \
                --camper_fa_db_cutoffs_loc $tmp_db_dir/CAMPER_blast_scores.tsv \
                --camper_hmm_loc $tmp_db_dir/CAMPER.hmm \
                --camper_hmm_cutoffs_loc $tmp_db_dir/CAMPER_hmm_scores.tsv
camper_distill  -a $tmpdir/annotations.tsv -o {output.distill} \
                --camper_distillate $tmp_db_dir/CAMPER_distillate.tsv
```

`mag_annotate__camper` is the target.

### Bakta

`mag_annotate__bakta` annotates the catalogue, which it sees as one genome:

```bash
bakta --db {params.db} --force --verbose \
      --output {params.out_dir} --prefix bakta --threads {threads} \
      {params.options} {input.contigs}
```

| Option | Default | Meaning |
|--------|---------|---------|
| `mag_annotate: bakta: additional_options` | `--skip-crispr --skip-plot` | Skip the search for CRISPR arrays and the circular plot |

`mag_annotate__bakta_mags__run` does the same for the binned contigs of each assembly. Its docstring calls these dereplicated MAGs, but its input is the output of MAGScoT, so they aren't dereplicated. `mag_annotate__bakta_mags` is the target.

### `mag_annotate__eggnog`

```bash
emapper.py -m diamond --data_dir {params.tmp_dir} \
           --itype metagenome --genepred prodigal \
           --dbmem --no_file_comments \
           --cpu {threads} -i {input.contigs} \
           --output_dir {params.out_dir} -o {params.prefix}
```

The rule first copies the database to `tmp_storage`. `--dbmem` loads eggNOG's annotation database into memory, and `--itype metagenome --genepred prodigal` makes eggNOG-mapper predict the genes itself.

This one call does both steps that @sec-tool-eggnog explains, the search for orthologs and the annotation, so the result is in `eggnog.emapper.annotations`. Before version 0.4.74, the rule had `--no_annot`, and it stopped after the search, so the genomes got no functional annotation.

The log of this rule is marked `protected()` and lies inside the output folder. So to run it again, you have to remove that folder, and you may need to do this with `rm -rf` as the file is read-only.

### `mag_annotate__proteinortho`

```bash
proteinortho {input.faa} -cpus={threads} -project=proteinortho
mv proteinortho.* {params.outdir}
```

This compares the proteins of all assemblies from Bakta. It needs at least two assemblies, so with only one assembly this rule can't work, and you should run single tools instead of the whole module. Note that it writes to the current folder, which is why the results are moved.

## What to look at after a run

1. **CheckM2:** how many genomes reach at least 90% completeness and at most 5% contamination? These are the usual marks of a high-quality draft, and at least 50% and at most 10% those of a medium-quality one.
2. **GTDB-Tk:** which groups are there, and do they fit the habitat? Are some classified only up to the family or the genus? These may be new species.
3. **DRAM:** `product.html` gives you the overview of what your genomes can do.

## Real output

@sec-tutorial-mag-annotate goes through the real output of this module, and how to read it.

## Summary

- Run CheckM2 first, and use it to decide which genomes to trust.
- GTDB-Tk and PhyloPhlAn give the taxonomy, DRAM, CAMPER, Bakta and eggNOG-mapper the function.
- Many rules work in a temporary folder, because the tools insist on creating their own.
- Some rules run on the catalogue, and others per assembly.
- `mag_annotate__proteinortho` needs at least two assemblies, and PhyloPhlAn's database path is written into its rule.
