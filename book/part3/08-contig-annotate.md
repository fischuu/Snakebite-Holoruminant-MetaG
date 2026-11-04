# Module `contig_annotate` {#sec-module-contig-annotate}

The module `mag_annotate` annotates genomes. But binning loses a lot: most contigs of a complex community never end up in a bin, and they would be missing from any analysis that starts at the catalogue. This module looks at **all contigs of each assembly**. It predicts their genes, annotates them, and counts how many reads hit each gene. This gives you a view of the functions of the whole community, whichever organism they belong to.

```bash
bash run_Snakebite-Holoruminant-MetaG.sh contig_annotate

# Or a single tool:
bash run_Snakebite-Holoruminant-MetaG.sh contig_annotate__eggnog
```

## The flow

```
results/assemble/{assembler}/{assembly_id}.fa.gz
        │  contig_annotate__prodigal__run
        ▼
results/contig_annotate/prodigal/{assembly_id}/{assembly_id}.prodigal.fa   (proteins)
results/contig_annotate/prodigal/{assembly_id}/{assembly_id}.prodigal.gtf  (positions)
        │
        ├── contig_annotate__featurecounts__run      counts per gene
        ├── contig_annotate__eggnog                  orthologs and functions
        ├── contig_annotate__eggnog7__run            eggNOG version 7
        ├── contig_annotate__camper__annotate        polyphenol genes
        ├── contig_annotate__diamond__assign         a chosen protein database
        ├── contig_annotate__hmmer__assign           chosen protein profiles
        └── contig_annotate__ncyc__run               nitrogen cycle, only in contig_annotate_extra
```

All results are per assembly, as this module has no catalogue. The target `contig_annotate` asks for all of them, except nCycDB.

## Finding the genes

### `contig_annotate__prodigal__run`

```bash
prodigal -i <(gunzip -c {input.assembly}) \
         -o {output.gtf} \
         -a {output.fa} \
         -p meta -f gff
grep -v '^#' {output.gtf} > {output.gtfplain}
```

@sec-tool-prodigal explains the tool. The rule writes proteins to the `.fa` file and positions to the `.gtf` file. Despite the name, that file is in GFF format, as `-f gff` says. The `_plain` version lacks the comment lines. `contig_annotate__prodigal` is the target.

### `contig_annotate__cut_prodigal`

An assembly can contain many millions of genes, and the search with eggNOG-mapper is slow. So this step cuts the proteins into chunks, which run as separate jobs, using `workflow/scripts/cutProdigal.sh`.

| Option | Default | Meaning |
|--------|---------|---------|
| `contig_annotate: prodigal: split` | 1000000 | Size of a chunk, in proteins |

You can't know how many chunks there will be before the step has run. This is why it's a **checkpoint**, the only one in the pipeline, as @sec-checkpoints explains. The functions `contig_annotate_aggregate_annotations_eggnog_search` and `contig_annotate_aggregate_assembly_eggnog_search` read the list of chunks after the checkpoint has finished.

## eggNOG-mapper

These rules do what @sec-tool-eggnog describes, in its two steps. Each chunk has its own job in each step.

### `contig_annotate__eggnog_find_homology`

```bash
emapper.py -m diamond --data_dir $DATA_DIR --override --no_annot --no_file_comments --cpu {threads} -i {input.files} ...
```

This is the search with DIAMOND. It only needs the fast DIAMOND database, and this is copied to `nvme_storage` first, if that's configured. `--no_annot` stops the program after the search, and leaves a `.emapper.seed_orthologs` file.

### `contig_annotate__eggnog_orthology_chunk`

```bash
emapper.py --data_dir $DATA_DIR \
           --annotate_hits_table {input.seed} \
           --no_file_comments \
           -o {params.out} --output_dir {params.outdir} \
           --override --cpu {threads}
```

This step turns the hits into annotations. It reads a big database all the time, so it should be on fast storage, and many jobs may share one copy on a node. This explains why this rule is so long: it has to make sure that exactly one job copies the database, that the others wait, and that the last job deletes it.

- A **counter** file says how many jobs are using the copy. `flock` protects it, so two jobs can't change it at the same moment.
- A **lock** folder says who does the copying. `mkdir` either creates a folder or fails, so only one job can succeed.
- A **done** file tells the waiting jobs that the copy is finished.

If a job gets killed, the counter stays too high, and the copy in `/dev/shm` remains until the node cleans it up. With `copy_dbs: "False"`, all this is skipped.

### `contig_annotate__eggnog_merge_annotations`

This rule concatenates the chunks into `eggnog_output.emapper.annotations`. `contig_annotate__eggnog` is the target.

### `contig_annotate__eggnog7__run`

Version 7 of eggNOG has a new tool, which is called with `workflow/scripts/eggnog7_annotator.sh`. It searches a DIAMOND database and looks up the hits in a master table. Its path comes from the entry `eggnog7` in `features.yaml`. `contig_annotate__eggnog7` is the target.

## Counting reads per gene

### `contig_annotate__cram_to_bam`

featureCounts can't read CRAM, so with `out_type: cram` this rule makes a temporary BAM file. With `out_type: bam` the rule doesn't exist, as it's inside a Python `if`. This is a nice example of @sec-python: the Snakefile decides which rules exist when it's read.

### `contig_annotate__featurecounts__run`

```bash
featureCounts -p -T {threads} -F GFF3 \
              -a {input.gtf} -o {output.file} \
              -t CDS -g ID \
              {input.bam}
```

This counts the read pairs that fall on each gene, per library and assembly. @sec-tool-featurecounts explains the options. Only libraries that belong to an assembly are counted against it. `contig_annotate__featurecounts` is the target.

## Other annotations

### `contig_annotate__camper__annotate`

The same tool as in @sec-module-mag-annotate, here on the proteins from Prodigal. `contig_annotate__camper` is the target.

### `contig_annotate__diamond__assign`

This rule uses `diamond blastp` to compare proteins with each database in `diamond_contig_protein` in `features.yaml`, and it stages them in the same way as the rule for the reads, which @sec-module-read-annotate describes. `contig_annotate__diamond` is the target.

The rule `contig_annotate__diamond__summarise` exists, but the target doesn't ask for its output. So it only runs if you request its output files by name. It also needs an R script for your database, and at the moment there are scripts for `cazy`, `funcgenes` and `kegg`, but none for the default `hyddb`.

### `contig_annotate__hmmer__assign`

```bash
hmmsearch -o {output.out} -A {output.aln} \
    --tblout {output.tblout} --domtblout {output.domtblout} --pfamtblout {output.pfam} \
    --acc --domT {params.domt} \
    {input.database} {input.fa}
```

This searches the proteins with the profiles in the entry `hmmer` of `features.yaml`. By default, these are the three classes of hydrogenases. `--domT` is a minimum score, and it has a value for each database:

| Option | Default | Meaning |
|--------|---------|---------|
| `contig_annotate: hmmer: domt: fefe` | 15.9 | Minimum score for FeFe hydrogenases |
| `contig_annotate: hmmer: domt: nife` | 34.5 | For NiFe hydrogenases |
| `contig_annotate: hmmer: domt: fe` | 54.4 | For Fe hydrogenases |
| `contig_annotate: hmmer: domt: fallback` | 10.0 | For any other database |

If you add your own profiles, set a score for them that makes sense, as 10.0 is only a rough fallback. `contig_annotate__hmmer` is the target.

**`--domT` only filters the domains.** The table of sequences, `{assembly_id}.tblout.tsv`, can still hold hits below the threshold, as @sec-tutorial shows on real data. So use `{assembly_id}.domains-tblout.tsv` for the result, or apply the threshold yourself.

### nCycDB

`contig_annotate__ncyc__prepare_input` links the proteins into one folder and writes a sample sheet. `contig_annotate__ncyc__run` runs the Perl script `NCycProfiler.PL`. These are the same steps as for the reads, this time with `-s prot`. `contig_annotate__ncyc` is the target, and it's only part of `contig_annotate_extra`.

## What you get

| Path in `results/contig_annotate/` | Content |
|------|---------|
| `prodigal/{assembly_id}/{assembly_id}.prodigal.fa` | The proteins |
| `prodigal/{assembly_id}/{assembly_id}.prodigal.gtf` | Their positions |
| `featurecounts/{assembly_id}/{assembly_id}_{sample}.{library}.prodigal_fc.txt` | Reads per gene |
| `eggnog/{assembly_id}/eggnog_output.emapper.annotations` | The function of each gene |
| `eggnog7/{assembly_id}/{assembly_id}.eggnog.tsv.gz` | The same from eggNOG 7 |
| `camper/{assembly_id}/annotations.tsv` | Polyphenol genes |
| `diamond/{diamond_db}/{assembly_id}.out` | DIAMOND hits |
| `hmmer/{hmmer_db}/{assembly_id}.tblout.tsv` | HMMER hits |

To get the amount of a function in a sample, you join two tables: the annotation of a gene from eggNOG, and the count of that gene from featureCounts.

## Summary

- This module works on all contigs of each assembly, whether binned or not.
- Prodigal finds the genes, and featureCounts counts the reads on them.
- The proteins are cut into chunks for eggNOG-mapper, which is why the pipeline needs a checkpoint here.
- The chunks share a copy of the database on the node, and files with counters and locks keep them from getting in each other's way.
