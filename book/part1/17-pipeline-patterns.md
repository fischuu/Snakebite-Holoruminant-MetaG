# How this pipeline uses Snakemake {#sec-pipeline-patterns}

You now know all the features the pipeline uses. This chapter shows the conventions that hold it together, so that you can read any of its rules. To see them without the size of the real thing, the example in
`book/examples/snakemake/14_patterns/` is a tiny pipeline that is built in the same way. It ran on the mini cluster with real SLURM.

```text
$ tree -a config workflow
config
├── config.yaml
├── escalation.yaml
├── features.yaml
├── params.yaml
├── profiles
│   └── minicluster
│       └── config.yaml
└── samples.tsv
workflow
├── Snakefile
└── rules
    └── qc
        ├── __main__.smk
        ├── filter.smk
        └── fragile.smk

6 directories, 10 files
```

## The run script

You don't call `snakemake` directly. A script in the project folder holds all the options of a run, so each run is the same, and you only say what to run:

```bash
bash run_Snakebite-Holoruminant-MetaG.sh assemble__megahit
bash run_Snakebite-Holoruminant-MetaG.sh assemble__megahit -np
```

Anything after the target goes to Snakemake, so `-np` makes it a dry run. The important part of the real script looks like this:

```bash
snakemake -s $pipelineFolder/workflow/Snakefile \
          --jobs 150 \
          --use-singularity \
          --configfile $projectFolder/config/config.yaml \
          --profile $Profile \
          --singularity-args "-B /scratch,/projappl,/users,/dev/shm:/dev/shm,/run,$projectFolder/tmp:/tmp" \
          --singularity-prefix $projectFolder/docker_images/ \
          --latency-wait 60 \
          --scheduler greedy \
          --resources metaspades_slots=$metaspades_slots \
          --restart-times 0 \
          --retries 0  \
          $@
```

| Option | Why |
|--------|-----|
| `--jobs 150` | Up to 150 jobs at once |
| `--use-singularity` | Run each rule in its container (@sec-containers) |
| `--configfile` | The main configuration of this project |
| `--profile` | The SLURM settings of this cluster |
| `--singularity-args` | Which folders the containers can see |
| `--singularity-prefix` | Keep the containers in the project, not in your home folder |
| `--latency-wait 60` | Wait a minute for files on the shared disk |
| `--scheduler greedy` | Quicker planning with many jobs |
| `--resources metaspades_slots=...` | At most this many metaSPAdes jobs at once |
| `--restart-times 0 --retries 0` | No global retries, as the Snakefile sets them per rule |
| `$@` | Everything you typed after the script's name |

The first lines of the script set the project folder, the profile and the temporary folders of Apptainer. You have to adjust them for each project (@sec-setup).

The script also reads two values from `config.yaml` with a small helper function. Since it uses `grep` and `sed`, it only works for simple one-line settings:

```bash
pipelineFolder="$(read_yaml pipeline_folder "$configFile")"
metaspades_slots="$(read_yaml metaspades_slots "$configFile")"
```

## What happens when Snakemake reads the workflow

`workflow/Snakefile` does these things in order, each time any Snakemake reads it:

1. It sets up `debug()`, which prints only with `PIPELINE_DEBUG=1`.
2. It works out the pipeline's version from the first numbered line of the `CHANGELOG`.
3. It loads `params.yaml`, `.docker.yml`, `features.yaml` and `samples.tsv`.
4. It checks the sample sheet with `validate_samples()`. Duplicate libraries or files stop everything right away, because they would otherwise lead to silently lost data.
5. It expands `assembly_ids`, and builds the lists `SAMPLE_LIBRARY`, `ASSEMBLY_LIBRARIES` and `ASSEMBLIES`.
6. It picks the temporary storage for each database-heavy tool with `choose_temp()`.
7. It loads `escalation.yaml`.
8. It defines the `debug` shell function for all rules with `shell.prefix`.
9. It includes `folders.smk` and all modules.
10. It defines `rule all`, and sets the retries of each rule from its escalation order.

## Resource sets and escalation

This is the idea you need most for reading rules. In a usual Snakefile, each rule has its own numbers for memory and time. If you then move to another cluster or other data, you have to change 170 rules. This pipeline separates the two.

`config.yaml` defines named **resource sets**, each with a size:

```yaml
resource_sets:
  small:
    runtime: 300
    mem_mb: 16000
    cpus: 1
    partition: "small"
    nvme: "nvme:0"

  medium:
    runtime: 4000
    mem_mb: 160000
    cpus: 10
    partition: "small"
    nvme: "nvme:0"
```

`escalation.yaml` says which sets each rule uses, in order:

```yaml
assemble__megahit__run: large
eukaryote__remag__filter: medium, large, longrun
```

The first attempt of `eukaryote__remag__filter` uses `medium`, the second `large` and the third `longrun`. A rule that isn't listed uses `small, medium, large`. So tuning for a new cluster or dataset means editing these two files, without touching any rule.

Three small functions in `workflow/rules/helpers/__functions__.smk` connect it:

```python
def get_escalation_order(rule_name):
    return ESCALATION_CONFIG.get(rule_name, ["small", "medium", "large"])

def get_resources(wildcards, attempt, rule_name):
    escalation_order = get_escalation_order(rule_name)
    profile_idx = min(attempt - 1, len(escalation_order) - 1)
    profile_name = escalation_order[profile_idx]
    resources = config["resource_sets"][profile_name].copy()
    ...
    resources["attempt"] = attempt
    return resources

def esc(key, rule_name):
    """Return a lambda for Snakemake resources/threads, bound to a specific rule name."""
    return lambda wc, attempt: get_resources(wc, attempt, rule_name)[key]
```

`esc("mem_mb", "my_rule")` returns a function, which Snakemake calls with the attempt number. It finds the right set, and returns the value. That explains the block that you will see in every rule:

```python
    threads: esc("cpus", "assemble__drep__run")
    resources:
        runtime=esc("runtime", "assemble__drep__run"),
        mem_mb=esc("mem_mb", "assemble__drep__run"),
        cpus_per_task=esc("cpus", "assemble__drep__run"),
        slurm_partition=esc("partition", "assemble__drep__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__drep__run')['nvme']}",
        attempt=esc("attempt", "assemble__drep__run"),
```

It looks long, but it is the same in all rules, and you can skip over it while reading. The name in it is what connects a rule to `escalation.yaml`, so it has to be spelled like the rule.

### Retries are set in one place

No rule says how often it can be retried. The loop at the end of `workflow/Snakefile` decides this for all of them:

```python
for r in workflow.rules:
    # One attempt per resource set
    retries = 0 if workflow.remote_exec else len(get_escalation_order(r.name)) - 1
    r.restart_times = retries
    debug(f"Rule '{r.name}': retries set to {retries}")
```

So a rule gets one attempt per resource set, and a rule with a single resource set isn't retried. When you add a rule, you only have to add its line to `escalation.yaml`.

The condition `workflow.remote_exec` is there because of the trap from @sec-retries-trap. Each SLURM job runs its own Snakemake on this same file, and without the condition it would retry a failed command inside the job, with resources the job doesn't have. With it, only the Snakemake on the login node retries, and a retry is always a new SLURM job.

### Escalation in action

In the example, the rule `qc__fragile__run` fails on purpose as long as it has less than 500 MB. Its configuration lets it escalate:

```
qc__fragile__run: small, medium, large
```

```text
$ bash run_pipeline.sh qc --quiet rules
[...]
Job 3 has been submitted with SLURM jobid 3 (log: .snakemake/slurm_logs/rule_qc__fragile__run/3.log).
[...]
Trying to restart job 3.
Job 3 has been submitted with SLURM jobid 4 (log: .snakemake/slurm_logs/rule_qc__fragile__run/4.log).
[...]
4 of 4 steps (100%) done

$ ls results/qc
fragile.log
fragile.log.try1
fragile.txt
sampleA.fastq.gz
sampleA.log
sampleB.fastq.gz
sampleB.log

$ cat results/qc/fragile.log.try1
attempt 1: 200 MB, 1 CPUs, partition small
Pretending to run out of memory

$ cat results/qc/fragile.log
attempt 2: 500 MB, 2 CPUs, partition small
```

The log of the failed attempt stays as `fragile.log.try1`, and the successful one becomes `fragile.log`. SLURM's records show that the second attempt really did get more:

```text
$ sacct -X --format=JobID,Comment%24,Partition,AllocCPUS,ReqMem,State | tail -n 4
1            rule_qc__filter__run_wi+      small          1       200M  COMPLETED 
2            rule_qc__filter__run_wi+      small          1       200M  COMPLETED 
3               rule_qc__fragile__run      small          1       200M     FAILED 
4               rule_qc__fragile__run      small          2       500M  COMPLETED
```

Job 3 failed with 200 MB and 1 CPU, and job 4 then succeeded with 500 MB and 2 CPUs.

The test `tests/escalation/run_test.sh` checks the same behaviour with the real rules of the pipeline, also on real SLURM (@sec-tests-in-repo).

::: {.callout-note}
## Most rules don't escalate by default

In the current `config/escalation.yaml`, 93 of the 98 listed rules have a single resource set, so these rules aren't retried at all. If you want a rule to escalate on your data, give it several sets, for example `small, medium, large`.
:::

## Debug messages

Setting `PIPELINE_DEBUG=1` turns on extra messages, both when the Snakefile is read and in the rules:

```text
$ PIPELINE_DEBUG=1 bash run_pipeline.sh qc -n --quiet rules
[DEBUG] Samples: ['sampleA', 'sampleB']
[...]
```

In the Snakefile, it is a normal Python function. For the rules, `shell.prefix` puts a bash function in front of every rule's command:

```python
shell.prefix(
    'set -euo pipefail; '
    'debug() {{ '
    'if [ "${{PIPELINE_DEBUG:-0}}" = "1" ]; then echo "[DEBUG] $*" >&2; fi; '
    '}}; '
)
```

The first of those lines is essential. `shell.prefix` replaces Snakemake's default prefix, which is what normally turns on strict mode, so it has to be repeated here (@sec-strict-mode). This pipeline learned that the hard way.

So each rule can write `debug "sample={wildcards.sample} threads={threads}"`. The message goes to stderr, and so into the log file when the rule has redirected it. With the variable unset, nothing is printed. It reaches the rules because SLURM jobs and containers inherit the environment here.

```bash
PIPELINE_DEBUG=1 bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__kraken2
```

## Conventions at a glance

| Convention | Example | Where to read more |
|-----------|---------|--------------------|
| Rule names | `assemble__magscot__hmmsearch` | @sec-structure |
| One target rule per tool and module | `assemble__magscot`, `assemble` | @sec-targets |
| Path constants | `MAGSCOT / "{assembly_id}.fa.gz"` | @sec-path-constants |
| Shared paths defined once | `CONTIGS`, `MAG_CATALOGUE`, `CLEAN_FORWARD` | @sec-path-constants |
| A log and a benchmark per rule | `log:`, `benchmark:` | @sec-logs-resources |
| A container per module | `docker["assemble"]` | @sec-containers |
| Resources from resource sets | `esc("mem_mb", ...)` | This chapter |
| A log per attempt | `try_log={log}.try{resources.attempt}` | @sec-logs-resources |
| Debug messages | `debug "..."` | This chapter |
| Settings from `params.yaml` | `params["assemble"]["drep"]` | @sec-config |
| Scripts in `workflow/scripts/` | `{params.script_folder}/contig_ids.py` | Part III |

## How to read a rule of this pipeline

When you open a rule file for the first time, read in this order:

1. **The name and the docstring** tell you what it does.
2. **`output:`** tells you what it promises, and where the result ends up.
3. **`input:`** tells you what it needs, and which rule therefore comes before it.
4. **`shell:`** is the actual work. Skip `debug` lines, and look for the tool's command.
5. **`container:`** tells you which software it runs in.
6. **`params:`** connects it to settings.

You can skip `threads:` and `resources:`, because they are the same everywhere.

Part III of this book goes through all rules in this way, and Appendix @sec-rule-reference lists them all, generated from the code.

## Summary

- The run script holds all options of a run.
- Resource sets and `escalation.yaml` keep the numbers out of the rules.
- `esc()` connects a rule to them, using its own name.
- `PIPELINE_DEBUG=1` turns on extra messages.
