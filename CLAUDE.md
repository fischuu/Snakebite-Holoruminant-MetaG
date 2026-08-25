# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Snakemake pipeline (forked from https://github.com/3d-omics/mg_assembly/ and extended for the
Holoruminant project) for shotgun metagenomics: read QC/host decontamination, read-based taxonomic/
functional annotation, assembly, binning into MAGs, and MAG/contig annotation and quantification. It
runs on HPC (SLURM) with all tools delivered as Singularity/Apptainer containers (no conda envs are
actually used despite `__environment__.yml` files present per module — containers are the real
dependency mechanism, see `config/.docker.yml`).

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
`mag_annotate`, `contig_annotate`, `quantify`. Each module can be run as a whole or as a single tool
within it using `<module>__<tool>` naming, e.g.:

```bash
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__kraken2
bash run_Snakebite-Holoruminant-MetaG.sh assemble__metaspades
bash run_Snakebite-Holoruminant-MetaG.sh mag_annotate__gtdbtk
```

Running a submodule automatically triggers its upstream dependencies. A `report_<module>` target exists
for most modules but the reporting module is still under development and may not produce usable output.

Formatting: `snakefmt` (config in `.github/linters/.snakefmt.toml`, which sets `skip_string_normalization
= true` for the underlying black formatter) is what CI lints with.

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

`workflow/Snakefile` parses `samples.tsv` into `SAMPLES`, `SAMPLE_LIBRARY`, `ASSEMBLY_SAMPLE_LIBRARY`, and
`ASSEMBLIES` globals used throughout the rule files, and builds `HOST_NAMES` from `features["hosts"]`.

### Module layout under `workflow/rules/`

Each module is a directory with:
- `__main__.smk` — `include:`s the module's rule files and defines the aggregate `rule <module>:` (and
  sometimes `<module>_extra`) whose `input:` pulls together every tool's output.
- `__functions__.smk` — module-local wildcard/lookup helper functions used by that module's rules.
- one `.smk` file per tool (e.g. `kraken2.smk`, `magscot.smk`), each `include:`d from `__main__.smk`.
- `__environment__.yml` — present for historical/documentation reasons; containers, not conda, are what
  actually run (see `container:` in each rule and `config/.docker.yml`).

`workflow/Snakefile` includes modules in pipeline order: `helpers` → `reads` → `reference` → `preprocess`
→ `read_annotate` → `assemble` → `quantify` → `mag_annotate` → `contig_annotate` → `report`, plus
`devel/throw_error.smk` (a synthetic `test_error` rule for exercising the escalation/retry machinery).

`workflow/rules/folders.smk` centralizes every output-path constant (`FASTP`, `KRAKEN2`, `MAGSCOT`, etc.,
all `pathlib.Path` objects under `results/<module>/...`) — check here first when tracing where a rule's
output goes or when wiring a new rule into an existing module.

### Resource escalation (retry-with-bigger-resources)

Every rule uses `esc(key, rule_name)` / `esc_val(key, rule_name)` (from
`workflow/rules/helpers/__functions__.smk`) instead of hardcoding `resources:`/`threads:`. `esc` returns a
lambda keyed on the current retry `attempt`: it looks up `rule_name` in `escalation.yaml` to get an
ordered list of resource-set names, then indexes into that list by `attempt` (clamped to the last entry).
`retries:` on each rule is set to `len(get_escalation_order(rule_name))`, and at the bottom of
`workflow/Snakefile` a loop over `workflow.rules` forces `r.retries = 0` for any rule whose escalation list
has ≤1 entry (so only rules with real multi-tier escalation configured actually retry). When adding a new
rule, follow the existing pattern: `threads: esc("cpus", "<rule_name>")`,
`resources: runtime=esc("runtime", ...), mem_mb=esc("mem_mb", ...), ..., attempt=get_attempt`, `retries:
len(get_escalation_order("<rule_name>"))`, and add an entry to `escalation.yaml` if it needs more than the
default 3-tier escalation (or a single-entry line to disable retries).

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

### Version string

The pipeline version shown in logs/reports is parsed out of the `CHANGELOG` file at Snakemake startup
(`get_version_from_changelog()` in `workflow/Snakefile`, matching `Version X.Y.*:` and a leading patch
number) — bump `CHANGELOG`, not a separate version constant, when releasing.
