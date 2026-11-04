# Setting up a project {#sec-setup}

Part I showed how a Snakemake pipeline is built. From this chapter on we look at this one. Before any module can run, a project needs its reads, its
databases and its configuration. This chapter goes through all of that, file by file.

## Two folders

The pipeline separates two things, and it helps to keep them apart in your head.

The **pipeline folder** is a clone of the repository. It holds `workflow/`, the rules and scripts. You don't change anything here during an analysis,
and several projects can use the same clone. `pipeline_folder` in the configuration points to it.

The **project folder** is where one analysis lives, usually on scratch space. You start Snakemake here, and all paths in the configuration are relative
to it. After a run it looks like this:

```
Snakebite_project/
├── config/          your own copy of the configuration
├── reads/           the raw FASTQ files, or a link to them
├── resources/       databases and reference genomes, or a link to them
├── docker_images/   the containers, which Snakemake downloads on the first run
├── results/         everything the pipeline writes
├── tmp/             temporary files, bound to /tmp in the containers
├── .snakemake/      Snakemake's bookkeeping and job logs
└── run_Snakebite-Holoruminant-MetaG.sh
```

Because the configuration is copied into the project, you can read it years later and see how that analysis was run. Copy it again for each new project,
with `cp -r $PIPELINEFOLDER/config $PROJECTFOLDER`. This copies the hidden `.docker.yml` too.

## Getting the databases

The databases and reference genomes are prepared on a public server, and `docs/02-Installation.md` lists the commands. Plan for about 3 TB and up to
three days. Unpacking is much quicker on a fast local disk, if you have one.

They are the same for every project, so download them once and link them:

```bash
cd $PROJECTFOLDER
ln -s /scratch/project_2009831/RESOURCES/resources .
```

The link must point to a place that the containers can see, which @sec-containers explains. If the target isn't bound into the container, the tools
report that a database file doesn't exist, although you can see it from the login node. This is one of the most common first errors.

## The run script

`run_Snakebite-Holoruminant-MetaG.sh` is copied to the project too. @sec-pipeline-patterns explains why it exists. These are the lines you edit:

| Line | What to set |
|------|-------------|
| `projectFolder=` | The project folder |
| `Profile=` | The profile of your cluster, see below |
| `module load snakemake/9.11.6` | How Snakemake is made available on your system |
| `APPTAINER_TMPDIR`, `APPTAINER_CACHEDIR` | Where Apptainer unpacks images. The default in the home folder is usually too small |
| `XDG_CACHE_HOME` | Where Snakemake keeps its cache, for the same reason. Commented out by default |
| `--jobs 150` | How many jobs may be in the queue at once |
| `--singularity-args "-B ..."` | The folders the containers can see. Everything the pipeline reads must be under one of them |

A few options deserve a comment.

`--singularity-prefix $projectFolder/docker_images/` is where the images go. They take several gigabytes each, and with this setting each project
downloads its own copy. To share them between projects, point it to a common folder.

`--resources metaspades_slots=$metaspades_slots` limits how many metaSPAdes jobs run at once in the whole project. The value comes from `config.yaml`,
and @sec-module-assemble returns to it.

`--restart-times 0 --retries 0` look as if they switched off the resource escalation, but they don't. They only set the default, and the Snakefile sets
the number of attempts for every rule itself. @sec-pipeline-patterns explains this.

`--scheduler greedy` makes Snakemake use a quick way of choosing the next jobs. The default solver can take a long time with thousands of jobs.

`--latency-wait 60` gives a shared file system a minute to show a job's files on the login node.

Anything you write after the target is passed to Snakemake:

```bash
bash run_Snakebite-Holoruminant-MetaG.sh assemble__megahit -np     # a dry run with the commands
PIPELINE_DEBUG=1 bash run_Snakebite-Holoruminant-MetaG.sh reads    # with the debug messages of the rules
```

## `config/config.yaml`

This is the file that Snakemake receives with `--configfile`. It names the other files, and it holds the settings of the system.

### Paths to the other files

| Key | Default | Content |
|-----|---------|---------|
| `pipeline_folder` | a path | The clone of the repository. A trailing `/` is added if it's missing |
| `features-file` | `config/features.yaml` | Reference genomes and databases |
| `params-file` | `config/params.yaml` | Options of the tools |
| `docker-file` | `config/.docker.yml` | Which container each module uses |
| `sample-file` | `config/samples.tsv` | The samples |
| `dram-config` | `config/dram_config.txt` | Paths for DRAM, see @sec-tool-dram |
| `phylophlan-config` | `config/phylophlan/supertree_aa.cfg` | No rule reads this key at the moment |
| `proteinortho-config` | `config/proteinortho_config.txt` | No rule reads this key at the moment, and the file doesn't exist in `config/` |

`config/escalation.yaml` is missing from this list because the Snakefile always reads it from that path.

### Fast storage

Some tools work on databases that are too big to read quickly over a network file system. The pipeline can copy these to a fast disk on the compute node
first. Three settings say where temporary files go:

| Key | Default | Meaning |
|-----|---------|---------|
| `tmp_storage` | `$TMP` | Normal temporary files |
| `nvme_storage` | `$LOCAL_SCRATCH` | A fast local disk |
| `shm_storage` | `/dev/shm` | Memory used as a disk, which is the fastest |

These values are written into the shell commands, so a variable like `$LOCAL_SCRATCH` is only read on the compute node when the job runs. Check that the
variables exist on your cluster. The names here are the ones used on CSC's Puhti.

The switches say whether the fast storage is used at all:

| Key | Default | Meaning |
|-----|---------|---------|
| `copy_dbs` | `"True"` | Copy databases to the fast storage where a rule supports it |
| `kraken2_shm` | `"True"` | Kraken2 uses `/dev/shm`. With `"False"` it uses `nvme_storage` |
| `diamond_shm` | `"True"` | The same for DIAMOND |
| `eggnog_shm` | `"True"` | The same for eggNOG-mapper |

If you use `/dev/shm`, the database counts as memory of the job. On a shared node this can get in the way of other jobs, and the comment in the file warns
about this. That is why the resource set `full_node` exists. Don't rely on `/dev/shm` being large unless you have a whole node for yourself.

If a rule uses these settings, its chapter in this part says so.

### The assembler

```
assembler: "metaspades"
```

`metaspades` and `megahit` run these assemblers. Any other name means that you provide the assemblies yourself. Put them into
`results/assemble/<name>/<assembly_id>.fa.gz`. @sec-module-assemble describes this, including how the contigs have to be named.

Note that 4CAC, in the module `eukaryote`, needs the assembly graph of metaSPAdes and doesn't run with the other choices.

### Limits and resource sets

`metaspades_slots: 10` is the limit mentioned above.

`resource_sets` is the list of job sizes. These are the defaults, written for CSC's Puhti, with the time limit in minutes, the memory in MB and the local disk in GB:

| Set | Minutes | MB | CPUs | Partition | Disk (GB) |
|-----|------|--------|------|-----------|------|
| `small` | 300 | 16000 | 1 | `small` | 0 |
| `medium` | 4000 | 160000 | 10 | `small` | 0 |
| `medium_nvme` | 4000 | 160000 | 10 | `small` | 10 |
| `large` | 4000 | 320000 | 20 | `small` | 0 |
| `large_nvme` | 4000 | 320000 | 20 | `small` | 50 |
| `highmem` | 4000 | 1400000 | 20 | `hugemem` | 250 |
| `longrun` | 20000 | 320000 | 20 | `longrun` | 250 |
| `highmem_longrun` | 20000 | 1400000 | 20 | `hugemem_longrun` | 250 |
| `full_node` | 4000 | 360000 | 40 | `small` | 1000 |

On another cluster, change the partitions first, because SLURM refuses a job for a partition that doesn't exist. The values are also generous on purpose
and not calibrated. A real run will show you how much your rules really need, because `sacct` reports it, and then you can make them smaller. Queues get
much shorter when a job asks for less.

## `config/escalation.yaml`

Each line gives a rule its resource sets, in the order they are tried:

```
assemble__concoct__run: large
eukaryote__tiara__run: medium, large
```

@sec-pipeline-patterns explains the mechanism. In short: each set gets one attempt, each attempt is a new SLURM job, and a rule that isn't listed gets
`small, medium, large`.

Most rules have only one set, 93 of the 98 lines at the moment. A rule like this isn't retried: if it runs out of memory, the pipeline stops and you have
to act. To let a rule escalate, add a second set to its line:

```
assemble__concoct__run: large, highmem
```

There are two things to look out for. A failure that has nothing to do with resources, such as a wrong path, fails on every set, and you wait for every
attempt. And while you are testing, a single small set saves a lot of waiting.

## `config/features.yaml`

This file says which reference data to use. All paths are relative to the project folder.

### `hosts`

```
hosts:
  bovine: resources/reference/Bos_taurus.ARS-UCD1.3.dna.toplevel.fa.gz
  human: resources/reference/Homo_sapiens.GRCh38.dna.toplevel.fa.gz
  ...
```

The reads are decontaminated against these genomes, and **the order matters**. Each genome only gets the reads the previous one left over, as @sec-module-preprocess
shows. So if you want to know how many reads came from the human genome, a read that maps to both cow and human is counted as cow if cow is listed first. Put the
genome you care most about first.

The names you choose become folder names. Leave the section empty for samples without a host, and then the reads skip this step.

### `magscot`

Two sets of marker gene profiles for scoring bins, see @sec-tool-magscot.

### `databases`

One path per tool. Four tools take a list, and they then run once per entry. Each name you give becomes a folder name in `results/`:

| Key | Entries |
|-----|---------|
| `kraken2` | `standard`, needing about 140 GB of memory. `refseq500`, commented out by default, needs about 1.4 TB |
| `diamond` | Protein databases for the reads, by default `cazy` |
| `diamond_contig_protein` | Protein databases for the contigs, by default `hyddb` |
| `hmmer` | Profile files for the contigs, by default the three hydrogenase classes `fe`, `fefe` and `nife` |
| `phylophlan` | `amphora2` and `phylophlan` |

## `config/params.yaml`

The options of the tools, sorted by module. The chapter of each module in this part lists them with their meaning. Not every option of every tool is here: an
option that isn't listed is either written directly into the rule or left at the default of the tool.

## `config/.docker.yml`

This file says which container each part of the pipeline uses, like `assemble: "docker://fischuu/hrp_assemble:0.2"`. Rules refer to it as `docker["assemble"]`.
@sec-tool-versions lists what's inside. You only change this when you want to try another version of a tool. If you do, write down why.

## `config/samples.tsv`

This is the table of your samples, with one line per library and tabs between the columns:

| Column | Meaning |
|--------|---------|
| `sample_id` | The sample |
| `library_id` | The library. Use `L001`, `L002` when one sample was sequenced in several lanes |
| `forward_filename` | Path to the forward reads, relative to the project folder |
| `reverse_filename` | Path to the reverse reads |
| `forward_adapter` | Adapter sequence of the forward reads |
| `reverse_adapter` | Adapter sequence of the reverse reads |
| `assembly_ids` | Which assemblies these reads go into |

The last column decides how samples are assembled:

- Give each sample its own name, and you get one assembly per sample.
- Give several samples the same name, and you get one co-assembly of them.
- Give several names with commas, like `S1, coasm`, and the library goes into both.
- Leave it empty, and the library is processed but not assembled.

The pipeline checks this table when it starts. It refuses a sheet in which a pair of `sample_id` and `library_id` appears twice, or in which a file is listed twice. Without this check, the
reads of the second row would be ignored without a warning, because all files are named after this pair. Don't use the Illumina S-number as `library_id`, because all lanes of a sample share it.

`workflow/scripts/createSampleSheet.sh` writes a table from the files in `reads/`. It expects names like `<name>_R1_001.fastq.gz`, so you may have to change two lines for other names, and
`docs/03-Setup.md` shows how. `workflow/scripts/concatenateFiles.sh` joins several lanes into one file before that.

## `config/profiles/`

A profile holds the settings of a cluster, as @sec-cluster explains. The repository has `Puhti` and `Migale`. For another system, copy one to a new folder and adjust it. The file must be called `config.yaml`:

```
executor: slurm
jobs: 5
default-resources:
    runtime: 30
    mem_mb: 16000
    cpus_per_task: 1
    slurm_partition: "small"
    slurm_account: "project_2010176"
    gres: "'nvme:0'"
```

`slurm_account` is the project that pays for the jobs, so change it to yours. `gres` is specific to clusters with local disks that have to be requested. On a system without them, remove it here, and set `nvme`
in the resource sets accordingly.

## Checking the setup

Before you start real jobs, let Snakemake tell you what it would do:

```bash
bash run_Snakebite-Holoruminant-MetaG.sh -np
```

This reads all configuration files and checks that the sample table is valid, that all rules fit together and that the input files exist. The table at the end shows how many jobs each rule would get. If the numbers look wrong, such as one assembly when you
expected three, look at `assembly_ids`.

`tests/real_run/` contains scripts that do all of this for the example data, and @sec-tutorial uses them.

## Summary

- The pipeline folder holds the code, and the project folder holds one analysis and its own copy of the configuration.
- All paths are relative to the project folder, and everything has to be visible inside the containers.
- `config.yaml` describes the system, `features.yaml` the reference data, `params.yaml` the tool options, `escalation.yaml` the job sizes and `samples.tsv` your data.
- The order of the host genomes matters.
- The resource sets are starting values. Change the partitions for your cluster, and calibrate the sizes after a first run.
