# Modules `report` and `helpers` {#sec-module-report}

The last two groups of rules are different from the others. They don't add a scientific step: `report` summarizes, and `helpers` does small jobs for the other modules.

## The module `report`

Each module has one report, a PDF in the folder `Rreports/` that you can use as a basis for a paper and to plan the next run. The rule `all` makes the first eight reports of this table at the end of a run. You can also make one on its own:

```bash
bash run_Snakebite-Holoruminant-MetaG.sh report_preprocess
```

**Careful:** a report asks for all results of its module, so calling it starts that module if it hasn't finished.

| Rule doing the work | Short target | Report on |
|------|------|------|
| `report__reads` | `report_reads` | Samples, reads per sample, read quality |
| `report__reference` | `report_reference` | Host genomes and the project's databases |
| `report__preprocess` | `report_preprocess` | Trimming, host removal, what happened to the reads |
| `report__read_annotate` | `report_read_annotate` | Taxonomy and function from the reads |
| `report__assemble` | `report_assemble` | Assembly, binning, the genome catalogue |
| `report__quantify` | `report_quantify` | Abundance of genomes and contigs |
| `report__mag_annotate` | `report_mag_annotate` | Quality, taxonomy and annotation of the genomes |
| `report__contig_annotate` | `report_contig_annotate` | Genes and annotation of the contigs |
| `report__eukaryote` | `report_eukaryote` | Eukaryotic contigs and bins. The module is optional, so `all` and `report` leave this out |

The target `report` asks for all of them, except the last.

### What a report has

Every report has these parts:

1. **Results in brief**: the main numbers in sentences, with warnings, for example about a library with far fewer reads than the others.
2. **The results of each tool**: tables and figures. A tool without output gets a sentence saying so.
3. **Methods text**: a paragraph with tools, versions and the settings of this project, to adapt for a paper.
4. **How much data this module wrote, and where**: per folder and file type, and the largest files.
5. **Resources**: requested and used, with suggestions for the next run. The next section explains these.
6. **Tools, versions and references**.

Next to `Rreports/<module>.pdf`, the folder `Rreports/<module>/` has all tables in `tables/` as TSV files with unrounded numbers, all figures in `figures/` as PDF and PNG, and the suggestions in `escalation_suggestions.yaml`.

### Requested and used resources

*Requested* comes from Snakemake's logs. `.snakemake/log/` has a block for each job, with its rule, benchmark file and resources, including the attempt. For a job whose log is gone, the report takes the first resource set of the rule in `config/escalation.yaml`, and it says so. *Used* comes from the job's benchmark file, which @sec-pipeline-patterns describes.

From these, the report compares the highest memory, the longest run time and the most cores of any job of a rule with the sets in `config/config.yaml`. With a margin of 30% on memory and 50% on run time, each rule gets one of these results:

| Result | Meaning |
|--------|---------|
| `start higher` | Jobs failed on the first set and finished on a later one. Starting there saves the failed attempts |
| `raise` | A job used 85% or more of its memory or its run time |
| `reduce` | A smaller set would be enough. The former sets stay in the line as a fallback, so a suggestion that is too low costs one failed attempt, not the run |
| `keep` | The set fits |
| `not measured` | The benchmark has no memory, so nothing can be said |

Two kinds of rules keep something even if they used little. A rule that stages a database in `/dev/shm` keeps its memory: the cluster counts those files against the job, and the benchmark doesn't see them, as they belong to no process. A rule on a set with local disk keeps that disk.

If no set fits well, the report says what size of a new set would. The lines to copy to `config/escalation.yaml` are in `Rreports/<module>/escalation_suggestions.yaml`.

**The suggestions hold for data like this run's.** A test on a subset says little about the memory that an assembler needs for the full data.

### How the reports work

Each rule runs `workflow/scripts/R/render_report.R`, which renders `workflow/scripts/R/<module>.Rmd`, with the shared parts in `report_helpers.R`:

```bash
Rscript {params.script} module=reads project={params.project_folder} \
    pipeline={params.pipeline_folder} features={params.features} samples={params.sample_file} \
    output={output.pdf} version={params.version} snakemake={params.snakemake_version} \
    rules={params.rule_table:q}
```

`rules` is a list of the module's rules with their benchmark patterns, which `report_rule_table()` takes from the workflow itself. So a new rule's resources appear without a change to the report. The generic helper rules, such as `helpers__fastqc`, count for the module in whose folder their files are.

A report must not fail at the end of a long run because a tool wrote something unexpected. So every part runs in `section()`, which turns an error into a sentence in the PDF and a line in `Rreports/<module>/section_errors.txt`.

The container is `rocker/verse`, with the key `report`. Its LaTeX is small, and it can't download what's missing on a compute node without network. This is why a report uses `pdflatex` and only a few LaTeX packages. `tests/reports/run_test.sh` renders all reports without network, and that's the test to run after any change, since a computer with a full LaTeX hides such problems.

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
