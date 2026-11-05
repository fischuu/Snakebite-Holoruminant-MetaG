# Configuration {#sec-config}

Rules describe how the work is done, and settings describe what this particular project needs. Keeping these apart is what
makes a workflow reusable: a colleague can run your rules on other data by changing only the configuration. The example is in
`book/examples/snakemake/06_config/`.

## A config file

Settings go in a **YAML** file, a simple text format where indentation shows the structure:

```yaml
# Settings a user changes without touching the rules
samples:
  - sampleA
  - sampleB
filter:
  min_length: 50
```

A line with a colon gives a name a value, and a `-` starts a list item. YAML cares about spaces and doesn't accept tabs, so if
a config file fails to load, look there first.

The Snakefile loads it with `configfile:`, and the content is then available in a dictionary called `config`:

```python
configfile: "config/config.yaml"


rule all:
    input:
        expand("results/{sample}.fastq.gz", sample=config["samples"]),


rule filter_reads:
    input:
        "data/{sample}_R1.fastq.gz",
    output:
        "results/{sample}.fastq.gz",
    params:
        min_length=config["filter"]["min_length"],
    shell:
        """
        zcat {input} \
            | paste - - - - \
            | awk -F '\\t' -v min={params.min_length} 'length($2) >= min' \
            | tr '\\t' '\\n' \
            | gzip > {output}
        """
```

The nesting in the file becomes nested lookups: `config["filter"]["min_length"]` is 50.

## Why `params:` and not just `{config[...]}`?

The setting passes through `params:` and not straight into the command. This has a practical advantage, and we can see it here.

First we run the workflow, and count the lines of the result:

```text
$ snakemake --cores 1 --quiet rules
[...]
$ zcat results/sampleA.fastq.gz | wc -l
112
```

Now we change the setting from the command line. `--config` overrides values for one run:

```text
$ snakemake --cores 1 --dry-run --quiet rules --config filter='{min_length: 80}'
Config file config/config.yaml is extended by additional config specified via the command line.
host: localhost
Building DAG of jobs...
Job stats:
job             count
------------  -------
all                 1
filter_reads        2
total               3
[...]
Reasons:
    (check individual jobs above for details)
    input files updated by another job:
        all
    params have changed since last execution:
        filter_reads
[...]
```

Snakemake noticed the changed parameter, and wants to rerun exactly the jobs it affects. That only works because the value was
in `params:`, which Snakemake records for each output. After running it, the file has fewer reads, as it should:

```text
$ snakemake --cores 1 --quiet rules --config filter='{min_length: 80}'
[...]
$ zcat results/sampleA.fastq.gz | wc -l
48
```

Treat `--config` as a tool for quick experiments, since a setting used only on a command line leaves no trace in your project.
Results you want to keep should come from settings in a file.

## How this pipeline organises its configuration

A project of this pipeline has its own `config/` folder, which is a copy of the one in the repository. So each project keeps its
settings next to its results, and updating the pipeline doesn't change them. The settings are split by what they are about:

| File | Content | How the Snakefile reads it |
|------|---------|----------------------------|
| `config/config.yaml` | Paths to the other files, pipeline folder, temporary storage, assembler, resource sets | `--configfile` on the command line, as `config` |
| `config/samples.tsv` | The samples, libraries, reads, adapters and assemblies | pandas, as `samples` |
| `config/features.yaml` | Host genomes and database paths | yaml, as `features` |
| `config/params.yaml` | Tuning parameters of the tools | yaml, as `params` |
| `config/.docker.yml` | The container of each module | yaml, as `docker` |
| `config/escalation.yaml` | Which resource sets each rule uses | yaml, as `ESCALATION_CONFIG` |
| `config/profiles/<cluster>/` | How jobs are submitted on this cluster | `--profile` |

The main file holds the paths to the others, and the Snakefile loads them itself:

```python
params = yaml.load(open(config["params-file"], "r"), Loader=yaml.SafeLoader)
docker = yaml.load(open(config["docker-file"], "r"), Loader=yaml.SafeLoader)
features = yaml.load(open(config["features-file"], "r"), Loader=yaml.SafeLoader)
samples = pd.read_table(config["sample-file"], comment="#", dtype="str")
```

So there is a global variable called `params`, in addition to the `params:` directive of each rule. These are different things,
though they often appear on the same line:

```python
    params:
        settings=params["assemble"]["drep"],
```

The left `params:` is the rule's directive. The right `params[...]` is the dictionary loaded from `params.yaml`. @sec-setup
describes each configuration file in detail, with all its options.

### The default is a copy, and copies can grow old

Since each project has a copy of the configuration, a pipeline update that adds a new setting doesn't reach your existing
project. The symptom is a Python `KeyError` when Snakemake starts:

```text
KeyError in file "<pipeline>/workflow/rules/eukaryote/4cac.smk", line 90:
'eukaryote'
```

The fix is to copy the missing section from the pipeline's `config/` folder into your project's. The `RELEASE_NOTES` file in the
repository lists such changes.

## Summary

- Settings belong in configuration files, and code belongs in rules.
- Pass settings to commands through `params:`, so Snakemake can notice changes.
- This pipeline splits its settings over several files, and each project has its own copy.
