# HUMAnN {#sec-tool-humann}

## What it does

HUMAnN finds out what a community can do, by profiling gene families and metabolic pathways from the reads. It answers questions like "how much of a certain enzyme family is there, and which species contributes it?"

## How it works

The search works in tiers, starting with what's cheap and precise. HUMAnN uses these steps:

1. **Which species are there?** It takes the profile from MetaPhlAn.
2. **Nucleotide search.** It builds a custom database from the pangenomes of just these species, from the ChocoPhlAn database, and it maps the reads against that with Bowtie2. This is quick, and the result is linked to a species.
3. **Translated search.** The reads that didn't map are translated, and they are compared with a large protein database, UniRef, using DIAMOND. This finds genes of organisms without a pangenome. It's slower, and the results aren't linked to a species, so they appear as "unclassified".
4. **Pathways.** From the gene families it infers pathways, using the MetaCyc database.

The abundances are given in reads per kilobase (RPK), so they are corrected for the length of a gene but not yet for sequencing depth.

## Input

One file of reads, such as FASTQ, plus the databases. Pairing isn't used, so paired reads are simply joined. The MetaPhlAn profile is optional, and HUMAnN would otherwise run MetaPhlAn itself.

## Output

| File | Content |
|------|---------|
| `<name>_genefamilies.tsv` | Abundance of each gene family, in total and per species |
| `<name>_pathabundance.tsv` | Abundance of each pathway |
| `<name>_pathcoverage.tsv` | How complete each pathway is |

In all of these, a line without `|` is the total for that family. A line with `|` is the share of one species. The special lines `UNMAPPED` and `UNINTEGRATED` hold what couldn't be assigned, and they are a useful measure of how much of your sample HUMAnN could explain.

The tool comes with helpers: `humann_renorm_table` normalizes for depth, `humann_join_tables` joins samples, and `humann_regroup_table` translates gene families into other systems, such as KEGG orthologs.

## When to use it

Use it for comparing functions between samples, particularly for human-associated communities where the reference data are best. It's a read-based alternative to annotating an assembly, and it doesn't need any assembly, so it also sees rare organisms that can't be assembled.

The limits are in the databases: much of what's in a rumen sample isn't in ChocoPhlAn, and so it depends on the slower translated search. It's also heavy, with long run times and a need for lots of temporary disk space. For new or poorly known communities, the annotation of contigs in @sec-module-contig-annotate is often more informative.

## In this pipeline

The rule `read_annotate__humann__run` joins the clean reads of a library and runs:

```bash
humann --input {output.cat} --output {params.out_folder} \
       --threads {threads} \
       --protein-database {input.prot_dbs} \
       --nucleotide-database {input.nt_dbs} \
       --output-basename {params.out_name} \
       --taxonomic-profile {input.mp_out} \
       {params.additional_options}
```

The option `--remove-temp-output` deletes the large intermediate files at the end.

`read_annotate__humann__condense` then writes `humann_genefamilies.tsv`. Note that this is a plain concatenation of the tables, so the result has one block per library, each with its own header. For a real table with one column per sample, use `humann_join_tables` on the single files.

Only the gene families are declared as output, but the pathway tables are also in the same folder.

## Pitfalls

- **Temporary space.** The rule warns about this: `TMPDIR` has to be large enough for big data sets.
- **Normalizing.** The values are in RPK. To compare samples, you must normalize first, usually to counts per million (CPM) with `humann_renorm_table`.
- **Versions.** The versions of HUMAnN, MetaPhlAn and the ChocoPhlAn database have to fit together. If the profile comes from a version with other species names, HUMAnN finds no matching pangenomes.
- **Comparing `UNMAPPED` between samples.** It depends strongly on the database, and it's not a biological result.

## Reference

Beghini F, et al. (2021). Integrating taxonomic, functional, and strain-level profiling of diverse microbial communities with bioBakery 3. *eLife*. <https://doi.org/10.7554/eLife.65088>
