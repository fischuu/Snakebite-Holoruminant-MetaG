# Module details

Each module runs as a whole or tool by tool, and a target also runs everything it depends on:

```
bash run_Snakebite-Holoruminant-MetaG.sh <module>
bash run_Snakebite-Holoruminant-MetaG.sh <module>__<tool>
```

Results are written to `results/<module>/<tool>/`. Rule names follow `<module>__<tool>__<step>`.

## 'reads' module

Links the FASTQ files listed in `samples.tsv` to `results/reads/<sample>.<library>_{1,2}.fq.gz` under uniform
names, and runs FastQC on them (`*_fastqc.zip` and `*_fastqc.html` next to the links).

## 'reference' module

Recompresses the host genomes from `features.yaml` with bgzip into `results/reference/hosts/`.

## 'preprocess' module

- `preprocess__fastp`: quality and adapter trimming, with the adapters from `samples.tsv`.
- `preprocess__bowtie2`: host decontamination. The reads are mapped against each host in the order of
  `features.yaml`, and the pairs with neither mate on that host go on to the next one. The reads left after the
  last host end up in `results/preprocess/bowtie2/decontaminated_reads/`. Without a host, these are fastp's reads.
- `preprocess__samtools`: mapping statistics for every host.
- `preprocess__fastqc`: FastQC of the trimmed reads and of the reads left after each host.

## 'read_annotate' module

Read-based profiling with kraken2 and Krona, Nonpareil, SingleM, MetaPhlAn, HUMAnN, phyloFlash, Sylph, DIAMOND and
NCyc. Each tool has its own target, e.g. `read_annotate__kraken2`. The databases are set in `features.yaml`.

Kraken2 databases can be added below the `kraken2` entry of `features.yaml`. A comparison of kraken2 and MetaPhlAn
databases: https://github.com/R-Wright-1/kraken_metaphlan_comparison/wiki/Downloading-databases

The MetaPhlAn database was downloaded like this:

```
metaphlan --install --index mpa_vJun23_CHOCOPhlAnSGB_202403 --bowtie2db metaphlan4/
```

Documentation of SingleM: https://wwood.github.io/singlem/

Nonpareil: Rodriguez-R LM & Konstantinidis KT (2014). Nonpareil: A redundancy-based approach to assess the level of
coverage in metagenomic datasets. Bioinformatics 30 (5): 629-635.

## 'assemble' module

1. Assembly with metaSPAdes or MEGAHIT (`assembler` in `config.yaml`), one per `assembly_id` of `samples.tsv`. The
   libraries sharing an `assembly_id` form a co-assembly. Any other assembler name means self-provided assemblies
   in `results/assemble/<name>/`, see `docs/03-Setup.md`.
2. `assemble__bowtie2`: mapping of the libraries against their assembly.
3. Binning with CONCOCT, MaxBin2 and MetaBAT2 (`workflow/rules/assemble/binners/`).
4. `assemble__magscot`: MAGScoT scores the bins of all three binners by marker genes and refines them. The steps
   before its run (prodigal, hmmsearch against Pfam and TIGRFAM) follow the MAGScoT manual. The contigs in a
   refined bin get that bin in their id, the others are dropped.
5. `assemble__drep`: dRep dereplicates the bins of all assemblies. The genomes are in
   `results/assemble/drep/dereplicated_genomes/`, and together they form the MAG catalogue
   `results/assemble/drep/dereplicated_genomes.fa.gz`.

Contig ids have the form `<assembly>:bin_<bin>@contig_<number>`, with `bin_NA` before MAGScoT.

## 'quantify' module

Maps all libraries against the MAG catalogue (`quantify__bowtie2`), computes CoverM tables per genome and per contig
for the methods set in `params.yaml` (`quantify__coverm`), and adds samtools statistics (`quantify__samtools`).

## 'mag_annotate' module

Annotates the MAG catalogue with QUAST, CheckM2, GTDB-Tk, DRAM, Bakta, CAMPER, eggNOG-mapper, PhyloPhlAn and
Proteinortho. DRAM and Bakta also run per assembly on the binned contigs (`mag_annotate__dram_mags`,
`mag_annotate__bakta_mags`). The databases of GTDB-Tk, CheckM2 and DRAM have to be installed manually first.

The DRAM database needs quite some resources, so best build it in an sbatch script:

```
#!/bin/bash
#SBATCH --job-name=create_dram_db
#SBATCH --account=project_2009831
#SBATCH --partition=hugemem
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --mem=800G
#SBATCH --time=24:00:00
#SBATCH --output=create_dram_db.out
#SBATCH --error=create_dram_db.err

singularity shell -B /scratch,/projappl,/users,/dev/shm:/tmp,/run:/run .snakemake/singularity/675d014754a2522c1e382e4b6f21b014.simg
DRAM-setup.py export_config > my_old_config.txt
export DRAM_CONFIG_LOCATION=my_old_config.txt
DRAM-setup.py prepare_databases --output_dir resources/databases/dram/20230811/
```

## 'contig_annotate' module

Annotates the contigs of every assembly, binned or not: gene prediction with Prodigal, then eggNOG-mapper, DIAMOND,
HMMER, CAMPER and NCyc on the proteins, and gene counts with featureCounts.

## 'eukaryote' module
This module labels the contigs of every assembly as eukaryotic or prokaryotic with three tools, and bins
the eukaryotic contigs. It is not part of `all` and has to be requested explicitly:

```
bash run_Snakebite-Holoruminant-MetaG.sh eukaryote
```

Each tool writes one table per assembly, using the same contig ids as the rest of the pipeline:

| Tool | Output | Classes | Notes |
|------|--------|---------|-------|
| Tiara | `results/eukaryote/tiara/<assembly>.tsv` | archaea, bacteria, prokarya, eukarya, organelle (mitochondrion/plastid), unknown | Fast, sequence composition |
| 4CAC | `results/eukaryote/4cac/<assembly>.tsv` | prokarya, eukarya, phage, plasmid, uncertain | metaSPAdes assemblies only (uses the assembly graph) |
| REMAG | `results/eukaryote/remag/<assembly>.tsv` | eukaryote, non_eukaryote | REMAG also bins the eukaryotic contigs: `results/eukaryote/remag/<assembly>/bins/` |

No databases are needed. Contigs shorter than the minimum length (1000 bp by default, `eukaryote` section of
`config/params.yaml`) are not classified. REMAG runs on CPU here; it is noticeably faster on a GPU.

The prokaryotic binning in the 'assemble' module scores bins with bacterial/archaeal marker genes (MAGScoT),
so eukaryotic bins don't come out of it; use the REMAG bins for eukaryotes.

# DRAM database generation
Apptainer> DRAM-setup.py export_config > /scratch/project_2009831/Pipe_dev/my_dram_config.txt
Apptainer> export DRAM_CONFIG_LOCATION=/scratch/project_2009831/Pipe_dev/my_dram_config.txt
Apptainer> DRAM-setup.py prepare_databases --output_dir /scratch/project_2009831/Pipe_dev/resources/databases/dram/20230811/

https://github.com/WrightonLabCSU/DRAM/issues/26#issuecomment-685212290

# Bakta
The bakta database I downloaded is 5.1:
https://zenodo.org/records/10522951

# Reports and other output

## Module reports

Every module has a report, which you can use as a basis for a paper and to plan the next run. `Rreports/<module>.pdf`
has, for its module:

- **Results in brief**: the main numbers in sentences.
- **Results of each tool**: tables and figures. The reads report has the number of samples, the reads per sample and
  the quality summaries of FastQC. The preprocess report follows the reads through each step.
- **Methods text**: a paragraph with the tools, versions and settings of this project, to adapt for a paper.
- **How much data the module wrote, and where**: per folder and file type, and the largest files.
- **Resources**: what each rule requested and what it used, and a suggestion for the next run. Requested values come from
  Snakemake's logs in `.snakemake/log/`, and used values from the benchmark files. The lines to copy to
  `config/escalation.yaml` are also in `Rreports/<module>/escalation_suggestions.yaml`.
- **Tools, versions and references**.

All tables are also in `Rreports/<module>/tables/` as TSV files with unrounded numbers, and all figures in
`Rreports/<module>/figures/` as PDF and PNG.

| Target | Report on |
|--------|-----------|
| `report_reads` | Samples, read numbers, read quality |
| `report_reference` | Host genomes, the databases of the project |
| `report_preprocess` | Trimming, host removal, what happened to the reads |
| `report_read_annotate` | Taxonomy and function from the reads |
| `report_assemble` | Assembly, binning, the genome catalogue |
| `report_quantify` | Abundance of genomes and contigs |
| `report_mag_annotate` | Quality, taxonomy and annotation of the genomes |
| `report_contig_annotate` | Genes and annotation of the contigs |
| `report_eukaryote` | Eukaryotic contigs and bins. This module is optional, so `all` and `report` don't include it |

The rule `all` makes the first eight. A report asks for all results of its module, so calling it starts the module if it
hasn't finished. A tool without output gets a sentence saying so, and a part of a report that fails says why in the
PDF and in `Rreports/<module>/section_errors.txt`, so that a report doesn't stop a run at its end.

The suggestions hold for data like that of the run: a test on a subset says little about the full data.

The reports use the container `rocker/verse`, with the key `report` in `config/.docker.yml`.

## Benchmark

There is a benchmark output in some (and hopefully soon in all) rules, that uses the snakemake `benchmark` directive, which in turn uses the `psutils` tool and that generates a tab-separated output file with the follwoing content regarding memory and time consumption as well as I/O pressure:

| Column      | Type (Unit)        | Description                                                                                                                                           |
|-------------|---------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| `s`         | float (seconds)     | Running time in seconds                                                                                                                               |
| `h:m:s`     | string (-)          | Running time in hour, minutes, seconds format                                                                                                         |
| `max_rss`   | float (MB)          | Maximum *Resident Set Size* — the non-swapped physical memory a process has used                                                                      |
| `max_vms`   | float (MB)          | Maximum *Virtual Memory Size* — the total amount of virtual memory used by the process                                                                |
| `max_uss`   | float (MB)          | *Unique Set Size* — memory unique to a process, which would be freed if the process terminated                                                        |
| `max_pss`   | float (MB)          | *Proportional Set Size* — shared memory divided proportionally among processes that share it (Linux only)                                             |
| `io_in`     | float (MB)          | Number of MB read (cumulative)                                                                                                                        |
| `io_out`    | float (MB)          | Number of MB written (cumulative)                                                                                                                     |
| `mean_load` | float (-)           | CPU usage over time, divided by the total running time (first row)                                                                                    |
| `cpu_time`  | float (-)           | CPU time summed for user and system                                                                                                                   |
