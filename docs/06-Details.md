# Module details

THIS SECTION NEEDS REVISITING AND IS CURRENTLY UNSTRUCTURED!!!

## 'reads' -module

The reads module can be started by

```
bash run_Pipeline-Holoruminant-meta.sh reads
```

and it triggers a set of rules:

### _reads__link
This rule makes a link to the original file, with a prettier name than default

It creates output files like this

```
forward_= results/reads/"{sample}.{library}_1.fq.gz",
reverse_= results/reads/"{sample}.{library}_2.fq.gz",
```

with `sample` and `library` being taken from the `sample.tsv` file.

### _helpers__fastqc
This rules creates fastqc reports for the input files and stores them also
in the results/reads folder as `*.zip` and `*.html` files.

## 'reference' - module
The reference module can be started by

```
bash run_Pipeline-Holoruminant-meta.sh reads
```

This module has essentially the only function to take the gezipped host genomes and
rezip them to bgzip

### _reference__hosts__recompress
This function loops through the provided host genomes and then recompresses them.

The results are then stored under `results/reference/hosts/`

## 'preprocess' - module
A larger subworkflow that consists of several steps. It can be run by

```
bash run_Pipeline-Holoruminant-meta.sh preprocess
```

### fastp subworflow
rule _preprocess__fastp__run:
    Run fastp on one library. THis is essentially the quality and adapter trimming. The output of quality trimming
    is then fed into the host decontamination.

### kraken2 subworkflow
TODO: CHECK; WHAT DATABASE TO USE?! https://github.com/R-Wright-1/kraken_metaphlan_comparison/wiki/Downloading-databases

wget https://genome-idx.s3.amazonaws.com/kraken/k2_nt_20231129.tar.gz

https://github.com/R-Wright-1/kraken_metaphlan_comparison/wiki/Downloading-databases

rule _preprocess__kraken2__assign:
    """
    Run kraken2 over all samples. Here, also the fastp reads are used, so we have not removed host contamination, when we assign kraken2 to the reads. Different databases used with kraken can be added into the configuration file `features.yaml`, intented after the kraken2 entry

### bowtie_2 subworkflow

This subworflow does a couple of things:

rule _preprocess__bowtie2__build:
    Build PRE_BOWTIE2 index for the host reference

rule _preprocess__bowtie2__map:
    Map one library to reference genome using bowtie2
    
rule _preprocess__bowtie2__extract_nonhost:
    Keep only pairs unmapped to the human reference genome, sort by name rather
    than by coordinate, and convert to FASTQ.

### Nonpareil subworkflow
rule _preprocess__nonpareil__run:
    Run nonpareil over one sample. For this step, the host decontaminated reads are used!
    Rodriguez-R LM & Konstantinidis KT (2014). Nonpareil: A redundancy-based approach to assess the level of coverage in metagenomic datasets. Bioinformatics 30 (5): 629-635.
    
### samtools subworflow
rule _preprocess__samtools__stats_cram:
    Compute the stats of a cram file using samtools stats. Here, we'll get mapping statistics for the host alignemtns.
    
### singlem subworkflow
TODO: CHECK WHAT DATABASE TO USE!!!

This part consists again out of several steps.. In details, these are

SingleM is a tool for profiling shotgun metagenomes. It has a particular strength in detecting microbial lineages which are not in reference databases. The method it uses also makes it suitable for some related tasks, such as assessing eukaryotic contamination, finding bias in genome recovery, computing ecological diversity metrics, and lineage-targeted MAG recovery.

Documentation can be found at https://wwood.github.io/singlem/

Citation

SingleM and Sandpiper: Robust microbial taxonomic profiles from metagenomic data. Ben J Woodcroft, Samuel T. N. Aroney, Rossen Zhao, Mitchell Cunningham, Joshua A. M. Mitchell, Linda Blackall, Gene W Tyson. bioRxiv 2024.01.30.578060; doi: https://doi.org/10.1101/2024.01.30.578060

rule _preprocess__singlem__pipe:
    Run singlem over one sample

rule _preprocess__singlem__condense:
    Aggregate all the singlem results into a single table
    
rule _preprocess__singlem__microbial_fraction:
    Run singlem microbial_fraction over one sample
    
rule _preprocess__singlem__aggregate_microbial_fraction:
    Aggregate all the microbial_fraction files into one tsv
    
### metaphlan4
For metaphlan 4 I downloaded the database like this

```
metaphlan --install --index mpa_vJun23_CHOCOPhlAnSGB_202403 --bowtie2db metaphlan4/
 metaphlan ERR2019411_1.fastq.gz,ERR2019411_2.fastq.gz --bowtie2out metagenomeERR.bowtie2.bz2 --nproc 20 --input_type fastq -o profiled_metagenome.txt --bowtie2db metaphlan4/
```
    
## 'assemble' -module

The assemble module runs first several assemblers and combines then the results. It can be initiated by running

```
bash run_Pipeline-Holoruminant-meta.sh assemble
```
    
It contains of several subworkflows, as

### megahit subworkflow
rule _assemble__megahit:
    Run megahit over samples associated to assembly, merging all libraries in the process. This creates the co-assemblies as defined in the samples.tsv file    

### bowtie2 - subworkflow

rule _assemble__bowtie2__build:
    Index a megahit assembly. Here, we prepare the megahit assembly for mapping
    
rule _assemble__bowtie2__map:
    Map one sample to one megahit assembly. Here, we map then the samples to the megahit assemblies
    
### concoct subworkflow

rule _assemble__concoct:
     This one takes all available assemblies and runs concot for them

### maxbin2 subworkflow
rule _assemble__maxbin2__run:
    """Run MaxBin2 over a single assembly, so for each assembly, we get the bins produced from maxbin2

### metabat2 subworkflow
rule _assemble__metabat2__run:
    Run metabat2 end-to-end on a single assembly, for all assemblies then


### drep subworflow
rule _assemble__drep__separate_bins:
    This one takes the magscot output and separates the bins
    
rule _assemble__drep__run:
    Dereplicate all the bins using dRep. This is the depreplication step for the bins

rule _assemble__drep__join_genomes:
    Join all the dereplicated genomes into a single file.

### magscot subworkflow
rule _assemble__magscot__prodigal:
    Run prodigal over a single assembly. So, we predict for each assembly the genes.    

rule _assemble__magscot__hmmsearch_pfam:
    Run hmmsearch over the predicted proteins of an assembly using Pfam as database  
  
rule _assemble__magscot__hmmsearch_tigr:
    Run hmmsearch over the predicted proteins of an assembly using TIGR as database  
CHECK HOW TO GET THE TIGR DATABASE!!!

rule _assemble__magscot__join_hmms:
    Join the results of hmmsearch over TIGR and Pfam
  
rule _assemble__magscot__merge_contig_to_bin:
    Merge the contig to bin files from CONCOCT, MaxBin2 and MetaBAT2  

rule _assemble__magscot__run:
    Run MAGSCOT over one assembly
  
rule _assemble__magscot__rename:
    Rename the contigs in the assembly to match the assembly and bin names  
  
### vamb subworkflow

## 'quantify' - module  
The quantify module quantifies the different assemblies and bins. You can use it like this

```
bash run_Pipeline-Holoruminant-meta.sh quantify
```

### bowtie2 subworkflow

rule _quantify__bowtie2__build:
    Index dereplicated genomes /mag
    
rule _quantify__bowtie2__map:
    Align one sample to the dereplicated genomes

### coverm subworkflow

rule _quantify__coverm__genome:
    Run CoverM genome for one library and one mag catalogue

rule _quantify__coverm__genome_aggregate:
    Run coverm genome and a single method

rule _quantify__coverm__contig:
    Run coverm contig for one library and one mag catalogue
    
rule _quantify__coverm__contig_aggregate:
    Run coverm contig and a single method
    
### samtools subworkflow
rule _quantify__samtools__stats_cram:
    Get stats from CRAM files using samtools stats.
    
## 'annotate' module    
This module takes care of the annotation steps

```
bash run_Pipeline-Holoruminant-meta.sh annotate
```
    
### quast subworkflow
rule annotate__quast:
    Run quast over one the dereplicated mags
    
### GTDBtk subworkflow
rule _annotate__gtdbtk__classify:
    Run GTDB-Tk over the dereplicated genomes

TODO: THE DATABASE NEEDS TO BE FETCHED AUTOMATICALLY, CURRENTLY THE USER NEEDS TO DO IT!    
TODO: UPDATE TO 2.4.0 (use release 220 instead)
wget https://data.ace.uq.edu.au/public/gtdb/data/releases/release214/214.0/auxillary_files/gtdbtk_r214_data.tar.gz
    
### DRAM subworkflow
rule _annotate__dram__annotate:
    Annotate dereplicate genomes with DRAM

rule _annotate__dram__distill:
    Distill DRAM annotations    

TODO: ALSO HERE THE DB NEEDS TO BE INSTALLED MANUALLY!
This needs quite much resources, so run it best in a sbatch script


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

### CheckM2 subworkflow
rule _annotate__checkm2__predict:
    Run CheckM2 over the dereplicated mags
Install the database manually first

# DRAM database generation
Apptainer> DRAM-setup.py export_config > /scratch/project_2009831/Pipe_dev/my_dram_config.txt
Apptainer> export DRAM_CONFIG_LOCATION=/scratch/project_2009831/Pipe_dev/my_dram_config.txt
Apptainer> DRAM-setup.py prepare_databases --output_dir /scratch/project_2009831/Pipe_dev/resources/databases/dram/20230811/

https://github.com/WrightonLabCSU/DRAM/issues/26#issuecomment-685212290

# Bakta
The bakta database I downloaded is 5.1:
https://zenodo.org/records/10522951

# Reports and other output

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
