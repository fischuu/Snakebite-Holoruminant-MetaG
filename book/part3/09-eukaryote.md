# Module `eukaryote` {#sec-module-eukaryote}

The binning of @sec-module-assemble scores bins with marker genes of Bacteria and Archaea. So eukaryotic bins don't come out of it: they would look like incomplete bins and be dropped. In soil or in samples with many fungi and protists, this can be a large part of the community. This module labels the contigs of each assembly as eukaryotic or prokaryotic, and it also bins the eukaryotic ones.

It isn't part of a complete run, so you have to call it yourself. It needs no database.

```bash
bash run_Snakebite-Holoruminant-MetaG.sh eukaryote

# Or a single tool:
bash run_Snakebite-Holoruminant-MetaG.sh eukaryote__tiara
```

## Why three tools

Telling apart the contigs of different domains is hard, especially for short ones. The three tools use different information, so where they agree you can be more confident:

| Target | Tool | Uses | Also does |
|--------|------|------|-----------|
| `eukaryote__tiara` | @sec-tool-tiara | The k-mers of each contig | Finds organelles |
| `eukaryote__4cac` | @sec-tool-4cac | K-mers, then the assembly graph | Finds plasmids and phages |
| `eukaryote__remag` | @sec-tool-remag | A deep language model of DNA | Bins the eukaryotic contigs |

## Tiara

### `eukaryote__tiara__run`

```bash
tiara \
    --input {input.assembly} --output {output.tsv} \
    --min_len {params.min_len} --prob_cutoff {params.prob_cutoff} \
    --probabilities --threads {threads}
```

This writes one table per assembly, and a short count of the classes as `log_{assembly_id}.tsv`, which is the first thing to look at. `eukaryote__tiara` is the target.

| Option | Default | Meaning |
|--------|---------|---------|
| `eukaryote: tiara: min_len` | 1000 | Ignore shorter contigs. Tiara's default is 3000, and 1000 is its documented lower limit |
| `eukaryote: tiara: prob_cutoff` | `[0.65, 0.65]` | The cutoff for each of the two stages. This is Tiara's default |

## 4CAC

4CAC refines its result with the assembly graph, and only metaSPAdes keeps this. The constant `FOURCAC_SUPPORTED` checks the configuration, and with MEGAHIT or your own assemblies, `eukaryote__4cac` asks for nothing, so it doesn't run, while the other two tools still do.

### `eukaryote__4cac__extract_graph`

The module `assemble` packed the working folder of metaSPAdes into an archive. This rule gets three files out of it. It extracts the contigs under the names of the scaffolds, as 4CAC expects these names. In this way, 4CAC classifies exactly the contigs that the rest of the pipeline uses, and the files are temporary.

### `eukaryote__4cac__run`

```bash
python {params.install_dir}/classify_xgb.py --fasta {input.contigs} \
    --outfile {params.workdir}/scaffolds.fasta.probs_xgb_4class.out --num_processes {threads}
python {params.install_dir}/classify_4CAC.py --assembler metaSPAdes \
    --asmdir {params.workdir}/ --outdir {params.workdir}/ \
    --phage {params.phage} --plasmid {params.plasmid}
python {params.script_folder}/fourcac_to_contig_ids.py ...
```

There are three steps: a first classification, the refinement on the graph, and finally the translation of metaSPAdes's names to the names of the pipeline. The last step needs the numbering of `contig_ids.py`, as @sec-module-assemble explains, so these two scripts have to change together.

The result has one line per contig, with the class `phage`, `plasmid`, `prokarya`, `eukarya` or `uncertain`, and the four scores. `eukaryote__4cac` is the target.

| Option | Default | Meaning |
|--------|---------|---------|
| `eukaryote: 4cac: install_dir` | `/pkg/4CAC` | Where the scripts are inside the container |
| `eukaryote: 4cac: phage` | 0.95 | Score needed for a phage |
| `eukaryote: 4cac: plasmid` | 0.95 | Score needed for a plasmid |

## REMAG

### `eukaryote__remag__filter`

```bash
rm -rf {params.out_dir}
remag --fasta {input.assembly} --output {params.out_dir} \
    --filter-only --min-contig-length {params.min_contig_length} \
    --hyenadna-batch-size {params.hyenadna_batch_size} --threads {threads}
```

This classifies the contigs. The rule then looks into REMAG's log for two problems:

```bash
if grep -q -E "HyenaDNA classifier not found|Failed to initialize HyenaDNA classifier|Classification error for bat..." ...
```

The reason is in the comment: if the classifier can't be loaded, or a batch fails, REMAG keeps those contigs as eukaryotic and only writes this to its log. A wrong result without an error is the worst kind, so the rule turns this into a failure.

### `eukaryote__remag__bin`

This rule runs in the folder of the previous one, where REMAG finds its results and doesn't need to classify again. It first adds up the length of the contigs that were called eukaryotic:

```bash
if awk -F '\\t' -v min_bp={params.min_bin_size} '
        NR > 1 && $3 == "eukaryote" {{ bp += $2 }}
        END {{ printf "%d bp classified eukaryotic\\n", bp; exit !(bp < min_bp) }}
    ' {input.tsv}; then
```

If this is less than the smallest allowed bin, no bin is possible, and REMAG would stop with an error. So the rule skips the binning, and writes an empty `bins/` folder and a `bins.csv` with only a header. Otherwise, it runs REMAG with one `--coverage` per mapping of the assembly, which the function `compose_coverage_args_for_remag` builds. So this rule needs the mappings of the module `assemble`. `eukaryote__remag` is the target.

| Option | Default | Meaning |
|--------|---------|---------|
| `eukaryote: remag: min_contig_length` | 1000 | Ignore shorter contigs. It must be the same in both steps, or REMAG refuses to continue. Don't change it without starting over |
| `eukaryote: remag: min_bin_size` | 500000 | Smallest bin, in bases |
| `eukaryote: remag: hyenadna_batch_size` | 1024 | Batch size of the classifier. Raise it if you have a GPU |
| `eukaryote: remag: extra` | `""` | Further options, for example `--epochs 50` |

## Reading the results together

You get three tables that use the same contig names, so you can join them. A contig is much more likely to be really eukaryotic if all three agree.

Be careful with short contigs: all three classifiers are least reliable there. And note what is **not** in this module: REMAG's bins aren't part of the catalogue of @sec-module-assemble, so they aren't quantified or annotated by the other modules. Check them with a tool for eukaryotes, such as EukCC or BUSCO, as CheckM2 doesn't apply to them.

## Summary

- This module is optional, and useful in samples with a real share of eukaryotes.
- Tiara, 4CAC and REMAG each label contigs in a different way, and REMAG also bins.
- 4CAC needs metaSPAdes, and it is skipped otherwise.
- Bins from REMAG stay outside the catalogue, and they need their own quality check.
