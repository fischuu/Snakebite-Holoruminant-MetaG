# A complete run on real data

These scripts run the whole pipeline on a SLURM cluster with the example data. You get a normal run that you can follow yourself, and a small archive
that records it. The archive is what the tutorial of the book and the tests of the real results are written from.

The data are three public cow rumen metagenomes of the Ruminomics project (ENA study `PRJEB21508`, runs `ERR2019410`, `ERR2019412` and `ERR2019415`,
Illumina HiSeq 2000, 2 x 101 bp). By default the run uses the subsets, which hold the first 10 million read pairs of each file. These are the first
reads of the file, not a random sample.

Each sample gets its own assembly, and all three also go into one co-assembly called `coasm`, so you get four assemblies. To change that, edit the
column `assembly_ids` of `config/samples.tsv` after step 1.

## What you need

- A clone of this repository on the cluster
- The databases and reference genomes, as described in `docs/02-Installation.md`
- Snakemake 9 with the SLURM plugin, and Apptainer or Singularity

The scripts haven't run on a real cluster yet, only on the mini cluster of the book with stand-ins for the tools. Expect to adjust something for your
system, and please keep the changes, because others will need them too.

## 1. Create the project folder

```bash
bash tests/real_run/setup_project.sh \
    --project /scratch/project_2009831/Snakebite_real_run \
    --account project_2009831 \
    --resources /scratch/project_2009831/RESOURCES/resources
```

Add `--reads <folder>` if you already have the example reads, otherwise they are downloaded. Add `--full` to use the full files, with 61 to 77 million
read pairs per sample.

The script reports what is missing. It also tells you to compare two things with your cluster: the partitions and sizes under `resource_sets` in
`config/config.yaml`, and the `module load` and `--singularity-args` lines of `run_Snakebite-Holoruminant-MetaG.sh`.

## 2. Run the stages

Snakemake has to stay alive while the jobs run, so start it in `tmux` or `screen`. Then run the stages in the project folder, one after another:

```bash
cd /scratch/project_2009831/Snakebite_real_run
PIPELINE=/users/fischerd/git/Snakebite-Holoruminant-MetaG

bash $PIPELINE/tests/real_run/run_stage.sh reads
bash $PIPELINE/tests/real_run/run_stage.sh reference
bash $PIPELINE/tests/real_run/run_stage.sh preprocess
```

Each call first prints a dry run's job table, then runs the jobs. A stage named after a module also makes that module's
report, as its last job, in `Rreports/`. The stages in order are:

| Stage | What it does |
|-------|--------------|
| `reads` | Links the reads and checks them |
| `reference` | Prepares the host genomes |
| `preprocess` | Trims the reads and removes host reads |
| `read_annotate` | Profiles the reads, with the big read-based databases |
| `assemble` | Assembles, bins and dereplicates |
| `quantify` | Maps the reads to the MAGs |
| `contig_annotate` | Predicts and annotates genes on the contigs |
| `mag_annotate` | Annotates the MAGs |
| `eukaryote` | Separates eukaryotic contigs. Not part of `all` |
| `read_annotate_extra` | nCycDB on the reads. Not part of `all` |
| `contig_annotate_extra` | nCycDB on the contigs. Not part of `all` |
| `report` | The PDF report of each module of `all`, in `Rreports/`. Only those that are missing or out of date get made |
| `report_eukaryote` | The report of the module `eukaryote`, which that stage has made already |

All in one go, stopping at the first failure:

```bash
for stage in reads reference preprocess read_annotate assemble quantify contig_annotate mag_annotate eukaryote read_annotate_extra contig_annotate_extra report report_eukaryote; do
    bash $PIPELINE/tests/real_run/run_stage.sh "$stage" || break
done
```

Any target works, for example `read_annotate__kraken2` for one tool, and more Snakemake options can follow it. If a stage fails, fix the cause and run
the same command again. Every call writes its own folder `book_run/<stage>/<date>`, so a failed attempt stays on record, and these are useful too.

## 3. Collect the record

```bash
bash $PIPELINE/tests/real_run/versions.sh
python3 $PIPELINE/tests/real_run/collect.py
```

`versions.sh` reads the tool versions out of each container. `collect.py` writes `book_run_<date>.tar.gz` in the project folder and prints its size. It
holds:

- For each stage: the dry run, Snakemake's output, and `sacct` with the time and memory each job really used
- The configuration of this run
- The end of each job log
- A list of all result files with sizes and checksums
- The first lines of each text result, or all of it for files up to 1 MB. Of reads and assemblies it keeps only the first few lines

Results stay in place, and `collect.py` doesn't change them. The archive contains paths and your project number, so check them before you share it. They
are removed from anything that goes into the book.
