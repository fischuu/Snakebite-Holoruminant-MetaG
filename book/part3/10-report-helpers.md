# Modules `report` and `helpers` {#sec-module-report}

The last two groups of rules are different from the others. They don't add a scientific step: `report` summarizes, and `helpers` does small jobs for the other modules.

## The module `report`

::: {.callout-warning}
## Under development
These reports aren't finished. They may not produce anything useful and they may crash. The rule `all` doesn't include them for this reason.
:::

Each module has one report, an R Markdown file in `workflow/scripts/R/`, which is rendered to a PDF in the folder `Rreports/`:

```bash
bash run_Snakebite-Holoruminant-MetaG.sh report_preprocess
```

All these rules are built in the same way. For example, `report__assemble` asks for all results of the module `assemble`, and runs:

```bash
R -e "project_folder <- '{params.project_folder}'; \
      pipeline_folder <- '{params.pipeline_folder}'; \
      features_file <- '{params.features}'; \
      sample_file <- '{params.sample_file}'; \
      rmarkdown::render('{params.script}', output_format='pdf_document', \
                         output_file=file.path('{params.project_folder}', '{output.pdf}'))"
```

**Careful:** since a report asks for all results of its module, calling it starts that module if it's not done yet.

| Rule doing the work | Short target | Report on |
|------|------|------|
| `report__reads` | `report_reads` | Raw reads |
| `report__reference` | `report_reference` | Host genomes |
| `report__preprocess` | `report_preprocess` | Trimming and host removal |
| `report__read_annotate` | `report_read_annotate` | Read-based annotation |
| `report__assemble` | `report_assemble` | Assembly and binning |
| `report__quantify` | `report_quantify` | Quantification |
| `report__mag_annotate` | `report_mag_annotate` | Annotation of MAGs |
| `report__contig_annotate` | `report_contig_annotate` | Annotation of contigs |

The target `report` asks for all of them. The container `r_report` is used only here, and for the R scripts of the DIAMOND summaries.

## The module `helpers` {#sec-module-helpers}

These are generic rules. Their output patterns have only one wildcard, `{prefix}`, and so they match any file with the right ending, wherever it is. A rule anywhere in the pipeline can ask for `something.cram.crai`, and `helpers__samtools__index_cram` will make it, as @sec-wildcards explains. So they are never called directly, and there's no target for this module.

| Rule | Makes | From | Runs |
|------|-------|------|------|
| `helpers__fastqc` | `{prefix}_fastqc.html`, `.zip` | `{prefix}.fq.gz` | `fastqc` |
| `helpers__samtools__index_bam` | `{prefix}.bam.bai` | `{prefix}.bam` | `samtools index` |
| `helpers__samtools__index_cram` | `{prefix}.cram.crai` | `{prefix}.cram` | `samtools index` |
| `helpers__samtools__faidx_fa` | `{prefix}.fa.fai` | `{prefix}.fa` | `samtools faidx` |
| `helpers__samtools__faidx_fagz` | `{prefix}.fa.gz.fai`, `.gzi` | `{prefix}.fa.gz` | `samtools faidx` |
| `helpers__samtools__idxstats_cram` | `{prefix}.idxstats.tsv` | `{prefix}.cram` | `samtools idxstats` |
| `helpers__samtools__flagstats_cram` | `{prefix}.flagstats.txt` | `{prefix}.cram` | `samtools flagstats` |

Having these in one place avoids writing the same rule many times. There's one thing to note. `helpers__samtools__faidx_fagz` only works on a file made with `bgzip`, not with plain `gzip`, and this is why host genomes get recompressed first.

The helper functions of Part I, `get_resources`, `esc`, `esc_val` and `get_escalation_order`, are in the same folder. @sec-pipeline-patterns explains them.

## The rule `test_error`

`workflow/rules/devel/throw_error.smk` has one rule, `test_error`, for testing the resource escalation by hand. It waits for a while and fails on the first attempt. You don't need it for an analysis, and no target asks for it. `tests/escalation/` has replaced it for regular checks.
