# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Snakemake pipeline (started from a fork of https://github.com/3d-omics/mg_assembly/, since largely
re-implemented and extended for the Holoruminant project, see "Provenance and acknowledgements" in
README.md) for shotgun metagenomics: read QC/host decontamination, read-based taxonomic/
functional annotation, assembly, binning into MAGs, and MAG/contig annotation and quantification. It
runs on HPC (SLURM) with all tools delivered as Singularity/Apptainer containers (no conda envs are
actually used despite `__environment__.yml` files present per module — containers are the real
dependency mechanism, see `config/.docker.yml`).

## The book

`book/` holds the handbook of this pipeline (Markdown chapters, PDF, examples), and it is a living document: **any change to
`workflow/` or `config/` has to update the book too.** Update the affected tool and module chapters, then run
`python3 book/tools/rule_reference.py`, `python3 book/tools/check_sync.py` and `python3 book/tools/check_transcripts.py`, and rebuild
the PDF with `bash book/build.sh`. If an image in `config/.docker.yml` changed, run `book/tools/container_versions.sh` and `book/tools/versions_table.py`.
After changing a rule that the real run covers, compare a project with `python3 tests/real_tools/check_results.py <project>`. Terminal output in a chapter must come from a real run: see `book/README.md`.

## Running the pipeline

There is no build step and no test suite (`.github/workflows/linters.yml` only runs `snakefmt` via
super-linter). All "development" happens by editing `.smk` rule files and dry-running Snakemake.

The pipeline is invoked through the wrapper script, never by calling `snakemake` directly in normal use:

```bash
bash run_Snakebite-Holoruminant-MetaG.sh <module_or_rule> [snakemake args...]

# dry run (always do this first when editing rules)
bash run_Snakebite-Holoruminant-MetaG.sh <module_or_rule> -np
```

The wrapper (`run_Snakebite-Holoruminant-MetaG.sh`) hardcodes `projectFolder` and `configFile` paths at
the top, reads `pipeline_folder`/`metaspades_slots` out of the project's `config/config.yaml`, and calls
`snakemake` with `--use-singularity`, a SLURM `--profile`, and `--restart-times 0 --retries 0` (retry/
escalation is instead handled per-rule, see "Resource escalation" below). This is a *project* wrapper —
each deployment (e.g. a specific HPC project folder) has its own copy with its own paths, so don't assume
the one in this repo checkout is what actually runs in production.

Modules (top-level rules in `rule all`): `reads`, `reference`, `preprocess`, `read_annotate`, `assemble`,
`mag_annotate`, `contig_annotate`, `quantify`. The `eukaryote` module exists but is deliberately left out
of `rule all` (opt-in, see "Eukaryote module" below). Each module can be run as a whole or as a single tool
within it using `<module>__<tool>` naming, e.g.:

```bash
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__kraken2
bash run_Snakebite-Holoruminant-MetaG.sh assemble__metaspades
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__gtdbtk
```

Running a submodule automatically triggers its upstream dependencies. Every module has a `report_<module>`
target, see "Reports" below.

Formatting: `snakefmt` (config in `.github/linters/.snakefmt.toml`, which sets `skip_string_normalization
= true` for the underlying black formatter) is what CI lints with. It checks the Snakemake files a pull
request changes, using snakefmt 0.8.0 with black 22.12.0 (pinned by super-linter v4.10.0), so format with
those versions.

### Debug messages

`PIPELINE_DEBUG=1` (unset/`0` by default), exported by the run script, turns on `[DEBUG]` messages both
while the Snakefile parses config (Python-side `debug()` in `workflow/Snakefile`) and inside every rule's
shell script (bash `debug()` function injected via `shell.prefix()` in `workflow/Snakefile`, so individual
`.smk` files just call `debug "..."` without redefining it). Regular `echo` messages in rules stay
always-on; `debug` calls are the extra, opt-in diagnostic detail. Relies on the submitting shell's
environment propagating through SLURM and into the Singularity container, which is the default here.
`shell.prefix()` replaces Snakemake's default prefix, so it has to start with `set -euo pipefail`. Without that,
a rule ignores every failing command except its last one, and no dry run can show this.

## Architecture

### Config-file driven, not code-driven

Everything a user needs to change lives in `config/`, loaded once at the top of `workflow/Snakefile`:

- `config/config.yaml` — top-level: paths to the other config files, `pipeline_folder`, temp-storage
  fallback chain (`shm_storage` → `nvme_storage` → `tmp_storage`), the `assembler` choice
  (`metaspades`/`megahit`/arbitrary name for self-provided assemblies), and `resource_sets` (named SLURM
  resource profiles: `small`, `medium`, `medium_nvme`, `large`, `large_nvme`, `highmem`, `longrun`,
  `highmem_longrun`, `full_node`).
- `config/features.yaml` — reference host genomes (`hosts:`, order matters — each host is sequentially
  decontaminated against, see below) and database paths for every annotation tool.
- `config/params.yaml` — per-tool tuning parameters (incomplete/uncalibrated by design; extend as needed).
- `config/escalation.yaml` — per-rule ordered list of `resource_sets` to escalate through on retry, keyed
  by full rule name (e.g. `read_annotate__kraken2__assign: full_node`). Rules not listed default to
  `["small", "medium", "large"]` (`get_escalation_order` in `workflow/rules/helpers/__functions__.smk`).
- `config/samples.tsv` — sample sheet: `sample_id`, `library_id`, forward/reverse filenames+adapters, and
  `assembly_ids` (comma-separated; same `assembly_id` across samples triggers a co-assembly). Generate it
  with `workflow/scripts/createSampleSheet.sh` (commonly needs per-project edits to the filename glob).
- `config/.docker.yml` — one container image per module, referenced in each rule's `container:` directive.
- `config/profiles/<cluster>/config.yaml` — SLURM executor profile; copy `Puhti/` for a new cluster.

`workflow/Snakefile` parses `samples.tsv` into `SAMPLE_LIBRARY`, `ASSEMBLY_LIBRARIES`, and
`ASSEMBLIES` globals used throughout the rule files, and builds `HOST_NAMES` from `features["hosts"]`.
`validate_samples()` runs first, on the raw sheet, and rejects duplicate `(sample_id, library_id)` pairs
or a FASTQ path repeated anywhere across `forward_filename`/`reverse_filename`: every per-library output
is keyed on that pair, so a duplicate would silently process only the first row's reads. It must stay
*before* the `assembly_ids` explode, after which `samples` legitimately holds one copy of each pair per
assembly; the per-library row lookups (`_reads_sample_row`, `_sample_row`) de-duplicate those copies.

### Module layout under `workflow/rules/`

Each module is a directory with:
- `__main__.smk` — `include:`s the module's rule files and defines the aggregate `rule <module>:` (and
  sometimes `<module>_extra`) whose `input:` pulls together every tool's output.
- `__functions__.smk` — module-local wildcard/lookup helper functions used by that module's rules.
- one `.smk` file per tool (e.g. `kraken2.smk`, `magscot.smk`), each `include:`d from `__main__.smk`.
- `__environment__.yml` — present for historical/documentation reasons; containers, not conda, are what
  actually run (see `container:` in each rule and `config/.docker.yml`).

`workflow/Snakefile` includes modules in pipeline order: `helpers` → `reads` → `reference` → `preprocess`
→ `read_annotate` → `assemble` → `quantify` → `mag_annotate` → `contig_annotate` → `eukaryote` → `report`, plus
`devel/throw_error.smk` (a synthetic `test_error` rule for exercising the escalation/retry machinery).

`workflow/rules/folders.smk` centralizes every output-path constant (`FASTP`, `KRAKEN2`, `MAGSCOT`, etc.,
all `pathlib.Path` objects under `results/<module>/...`) — check here first when tracing where a rule's
output goes or when wiring a new rule into an existing module.

### Resource escalation (retry-with-bigger-resources)

Every rule uses `esc(key, rule_name)` / `esc_val(key, rule_name)` (from
`workflow/rules/helpers/__functions__.smk`) instead of hardcoding `resources:`/`threads:`. `esc` returns a
lambda keyed on the current retry `attempt`: it looks up `rule_name` in `escalation.yaml` to get an
ordered list of resource-set names, then indexes into that list by `attempt` (clamped to the last entry).
Retries are set in one place only, the loop at the bottom of `workflow/Snakefile`: one attempt per resource
set, so a rule with a single entry isn't retried. Don't put `retries:` on a rule. A SLURM job runs its own
Snakemake on the same Snakefile, and with a rule-level `retries:` that inner Snakemake reruns a failed
command inside the same job, with the numbers of a resource set the job doesn't have. That's why the loop
sets `restart_times` to 0 when `workflow.remote_exec` is true. `tests/escalation/run_test.sh` tests this on
real SLURM. When adding a new rule, follow the existing pattern: `threads: esc("cpus", "<rule_name>")`,
`resources: runtime=esc("runtime", ...), mem_mb=esc("mem_mb", ...), ..., attempt=esc("attempt", ...)`, and
add an entry to `escalation.yaml` if it needs something else than the default 3-tier escalation (or a
single-entry line to disable retries).

### Host decontamination chain

`HOST_NAMES` (from `features.yaml["hosts"]`, order-preserving) drives sequential decontamination in
`preprocess`: reads are mapped against each host genome in order, and each step's "non-host" output feeds
the next host's input (`_get_input_file_for_host_mapping` in
`workflow/rules/preprocess/__functions__.smk`). The final non-host reads (after the last host in
`HOST_NAMES`, or straight from `fastp` if `HOST_NAMES` is empty) are what downstream modules
(`read_annotate`, `assemble`, `quantify`) consume — see `_get_final_file_from_pre`. Reordering
`features.yaml["hosts"]` changes which contamination levels are attributable at each stage.

### Fast-storage staging (shm/nvme) for large-DB tools

Kraken2, DIAMOND, and eggnog rules stage their reference databases onto faster local storage before
running (`KRAKEN2SHM`/`KRAKEN2NVME`, `DIAMONDSHM`/`DIAMONDNVME`, `EGGNOGSHM`/`EGGNOGNVME` globals in
`workflow/Snakefile`, resolved via `choose_temp()` from `config["shm_storage"]` →
`config["nvme_storage"]` → `config["tmp_storage"]`). Controlled per-tool by `kraken2_shm`/`diamond_shm`/
`eggnog_shm` and globally by `copy_dbs` in `config.yaml`. This logic lives inline in each rule's shell
block (see `read_annotate/kraken2.smk`) — it checks available space, falls back progressively, and on the
last retry attempt falls back to running directly from the original DB path rather than failing.

### Self-provided assemblies

`config["assembler"]` is normally `"metaspades"` or `"megahit"`, but any other string is treated as a
user-provided assembly source: the pipeline expects gzipped FASTAs at
`results/assemble/<assembler>/<assembly_id>.fa.gz` with contig headers following the
`{assembly_name}:bin_NA@contig_00000000`-style convention produced by the embedded assemblers (a
non-conforming naming scheme has caused unexpected behavior). Use
`workflow/scripts/rename_provided_assemblies.py` to reheader externally-produced assemblies.

### Eukaryote module

`eukaryote` labels each assembly's contigs as eukaryotic/prokaryotic with Tiara, 4CAC and REMAG (one
`results/eukaryote/<tool>/<assembly_id>.tsv` per tool, keyed on the pipeline's contig ids) and bins the
eukaryotic contigs with REMAG. MAGScoT scores bins with bacterial/archaeal markers only (threshold 0.5),
so eukaryotic bins from the `assemble` binners don't survive it; REMAG's bins are the eukaryotic route.
Non-obvious parts:
- 4CAC needs the metaSPAdes assembly graph, so it only runs for `assembler: metaspades`
  (`FOURCAC_SUPPORTED`). `eukaryote__4cac__extract_graph` pulls `contigs.fasta`/`contigs.paths`/the GFA out
  of the metaSPAdes tarball and hands them to 4CAC *as* `scaffolds.fasta`/`scaffolds.paths` (same format),
  so 4CAC classifies the contigs the pipeline uses. `workflow/scripts/fourcac_to_contig_ids.py` maps the
  `NODE_*` names back by repeating the metaspades rule's renaming (record order in `contigs.fasta`) — if
  that renaming ever changes, change the script with it.
- REMAG names its files after the input (`<assembly_id>.fa_*`). `eukaryote__remag__filter` clears and
  fills `results/eukaryote/remag/<assembly_id>/`; `eukaryote__remag__bin` resumes in that same folder
  (REMAG reuses its filtered FASTA there, and refuses if `--min-contig-length` differs, hence one shared
  `min_contig_length` param). REMAG silently keeps all contigs if its classifier fails to load; the filter
  rule turns that log line into a failure. Binning is skipped (empty outputs) when the eukaryotic contigs
  total less than `min_bin_size`.
- Containers: Tiara and REMAG are pinned biocontainers; 4CAC has no package, `docker["4cac"]` is a
  third-party image with the repo at `/pkg/4CAC` (`params["eukaryote"]["4cac"]["install_dir"]`).

### Version string

The pipeline version shown in logs/reports is parsed out of the `CHANGELOG` file at Snakemake startup
(`get_version_from_changelog()` in `workflow/Snakefile`, matching `Version X.Y.*:` and a leading patch
number) — bump `CHANGELOG`, not a separate version constant, when releasing.

## Reports

`workflow/rules/report/<module>.smk` runs `workflow/scripts/R/render_report.R`, which renders
`workflow/scripts/R/<module>.Rmd`. The shared parts are in `report_helpers.R`: tables, figures, data volume, requested
and used resources, and suggestions for `config/escalation.yaml`. Every chunk has `results="asis"`, every part of a report
is inside `section()`, which turns an error into a sentence, the first chunk reads each tool's output through
`load_tool()`, which does the same, and all tables go through `show_table()`, which also writes them to
`Rreports/<module>/tables/`.

- **If a rule's output changes, change the report's parser too**, and `tests/reports/`. Run
  `tests/reports/run_test.sh`, which renders all reports in the container without network, as on a compute node.
- **LaTeX in the container is minimal, and it can't download packages on a compute node.** There is no `booktabs`,
  `float`, `caption` or `xurl`, and `xelatex` lacks `unicode-math`. So the reports use `pdflatex`, write tables and figures
  as non-floating blocks, and replace characters that `pdflatex` has no glyph for. `LOCAL_R=1` with a full LaTeX hides
  such problems, so test in the container before a commit.
- **In dplyr, `summarise()` and `transmute()` see earlier results under the same name.** `summarise(hits = sum(hits),
  genes = sum(hits > 0))` gives a wrong number of genes, silently. Tests with several jobs or libraries catch this.
- A new rule needs no change for its resources to appear: `report_rule_table()` in `rules/report/__functions__.smk`
  passes the rules with a benchmark from the workflow.
- `workflow/scripts/R/report_tools.tsv` has the tool, container key, purpose and reference for the tables of tools. Tool
  versions come from `workflow/scripts/R/tool_versions.tsv`.
