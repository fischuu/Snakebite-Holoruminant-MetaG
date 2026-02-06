# Setting up the pipeline

There are a few central files that coordiante and configure the pipeline and we will go one-by-one through them.

## run_Snakebite-Holoruminant-MetaG.sh
This is the pipeline starting wrapper script. It takes care of enabling Snakemake (e.g. in case you
have it as a module on your server) and also wraps the different Snakemake options nicely. Furthermore, it
sets up the environment variables for tmp and cache folders of apptainer or singularity.
It can also can be used to prepare the rulegraph of the pipeline.

You need to enter the required values and paths according to the comments in the file. 

Pay also attention to the binding points in the snakemake call, that all required paths and entry points are
mounted to the apptainer container.

## config/config.yaml
Here are the paths to the different configuration files stored, which might not need any adjustments
from the user (e.g. for Holoruminant users). 

In addition, the specs for the resource set allocations are provided here. The defaults are currently
not calibrated and need still some closer evaluation. Adjust the values to your needs and names from
your hpc (like queue names).

Please, check also the escalation.yaml file, which organises the escalation levels for all rules.

### Self-provided assemblies
Starting from version 0.4.30 you can also provide already assembled genomes to the pipeline. For that,
you can choose any other name than "metaspades" or "megahit" in the `assembler`-option. Further you
would need to
create a folder in `results/assemble/<name>` where `<name>` corresponds to the same entry you picked
in the config file. For example, you created assemblies with some long-read pipeline (e.g. this one
here: https://github.com/fischuu/Snakebite-Long_metaG ) you could put into the config under assembler
`assembler: "long_reads"` and then you would prepare the folder

```
mkdir -p $PROJECTFOLDER/results/assemble/long_reads
```

Then, you can provide the assemblies as gezipped fasta files, in the format

```
{assembly_id}.fa.gz
```

where `{assembly_id}` refers to the assembly_id provided in the `sample.tsv` file.

Currently, the contig naming within the self-provided genomes is not very flexible (at least arbitrary naming
caused unexpected behaviour). For that reason, it is advisable to call the contigs like they would look like
they would come from the embedded assembler looking like this

```
>LPMS:bin_NA@contig_00000001
ATCGACTTCA....
>LPMS:bin_NA@contig_00000002
GTGTTGATCA....
>LPMS:bin_NA@contig_00000003
TAGCTACGTA...
```

meaning, it follows the naming scheme `>'assebly_name'>bin_NA@contig_00000000`.

We provide a script for renaming the header of self-provided assemblies that can be used like this

```
python ~/git/Snakebite-Holoruminant-MetaG/workflow/scripts/rename_provided_assemblies.py -i CPMS_orig.fa -a CPMS
```

where `-i` provided the original fasta file and `-a` the name of the assembly to be used. Sometimes the zipping
of the output file was very slow, so there is a also a `--no-gzip`-option so that the gzip function can be run
afterwards manually, what was much faster in test runs.


## config/escalation.yaml

In the escalation.yaml file are the different rules and their order of escalation. In case a rule
fails, the slurm executor resubmits the rule with the next resource set defined in this file. In case that
you cannot use the slurm exeutor you need to check if resubmission is possible with your choice of
executor. If this is not possible, you can shorten here the entries to single resource sets to work.

For test runs, it is also advisable to keep escalations on a single value to avoid wasting resources.

## config/features.yaml
Here we can adjust the reference genomes and databases that should be used from the pipeline. The
current defaults are for the Holoruminant project and have as such a very specific set of reference
genomes that are used for filtering and checking contaminations. Adjust yours in the `hosts:` section.

Take care of the order of the decontamination and bear in mind that during each step are reads filtered out for the
next phase. Hence, the order matters in case you want to analyse later the level of different contaminations!

Here, you can just use a own name, followed by colon and the path to it. Reference genomes are expected
to be gzipped.

In the `databases:` section the paths to the corresponding databases are used. The default paths meet
the folder structure you will obtain, when you download the databases from our server. The main adjustments
to do are a) the kraken path and b) phylophlan. Here, sub-databases can be given and the tools run one
after another the searches against these databases. In case of kraken, we provide a small standard
database as well as a rather large one called `refseq500`. Just comment out the ones you do not want to use.


## config/profiles/
Here are the HPC profiles stored. The current default configuration is adjusted to our system called Puhti
and is located in the subfolder `Puhti/` in the file `config.yaml`. For your own system, create a new
subfolder with the name of your system and copy the config file from `Puhti/` there to adjust. Please do
not rename the yaml file, it needs to be `config.yaml`. 

Here, set your typical default resources and check what requirements your generic slurm (or whatever executor
you use) command has. In essence, the `cluster-generic-submit-cmd` needs to match the requirements of your
system, e.g. the `slurm_account` option might be very specific on our system Puhti and might not be accepted
or required on your system.


## config/params.yaml
This file contains the tuning parameters of the different tools. This file is far from being complete and
is currently not calibrated. So, please check if the tools use the parameters you want them to use and add
if needed the parameters to the rule and the params file.

If you need additional parameters for your tool and you do not know how to include it, please open an issue
on the GitHub page.

## config/samples.tsv
This file contains the sample information and is required by the pipeline. 

The file has this structure

| sample_id  | library_id | forward_filename              | reverse_filename              | forward_adapter                           | reverse_adapter                           | assembly_ids |
|------------|------------|-------------------------------|-------------------------------|-------------------------------------------|-------------------------------------------|--------------|
| ERR2019410 | lib1       | reads/ERR2019410_1.fastq.gz   | reads/ERR2019410_2.fastq.gz   | AGATCGGAAGAGCACACGTCTGAACTCCAGTCA         | AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT         | ERR2019410   |
| ERR2019412 | lib1       | reads/ERR2019412_1.fastq.gz   | reads/ERR2019412_2.fastq.gz   | AGATCGGAAGAGCACACGTCTGAACTCCAGTCA         | AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT         | ERR2019412   |


where we can give the 

* `sample_id` , unique sample identified
* `library_id`, library identifier for repeated libraries
* `forward_filename`, relative path to the forward read file of that sample
* `reverse_filename`, relative path to the reverse read file of that sample
* `forward_adapter`, adapter sequence from the forward read
* `reverse_adapter`, adapter sequence from the reverse read
* `assembly_ids`, group name for the co-assembly this sample should be used in

I am not sure, tbh, if currently several assembly_ids per sample are allowed, this would need to be tested.
You can either assign an individual `assembly_id` to each sample (e.g. the sample_id again), when you will get
one assembly per sample, or you use the same `assembly_id` for different samples, to create a co-assembly
across them.

There is a convenience script in the script folder to create the sample sheet. For that, you can run

```
cd $PROJECTFOLDER
bash $PIPELINEFOLDER/workflow/scripts/createSampleSheet.sh
```

It creates the `samples.tsv` for the samples located in the `reads/` folder. You might need to adjust the
script maybe accoring to the names of the reads or the adapter sequences you use.

The most common error that can happen here is, that the file format from your samples is not as anticipated
in the `createSampleSheet.sh` script. If that happens, you will see an error similar to this one:

```
Looking for files in reads/...
No forward files found matching pattern *_R1_*.fastq.gz
No files found in reads/ matching the pattern *_R1_*.fastq.gz
```

In that case, you need to adjust your script. For that, copy it to the `$PROJECTFOLDER` and edit it there

```
cp $PIPELINEFOLDER/workflow/scripts/createSampleSheet.sh $PROJECTFOLDER
```

For example, for the example data it would need to be changed, as the file names are in the format
`<NAME>_1.fastq.gz` and `<NAME>_2.fastq.gz` instead of `<NAME>_R1_001.fastq.gz` (how it is assumed by the
script). That means,you would need to adjust row numbers 20 from 

```
for file in ${fastq_path}*_R1_*.fastq.gz; do
```

to 

```
for file in ${fastq_path}*_1_subset.fastq.gz; do
```

and row number 26 from 

```
reverse_file="${fastq_path}$(basename "${file/_R1_/_R2_}")"
```

to 

```
reverse_file="${fastq_path}$(basename "${file/_1_subset.fastq/_2_subset.fastq}")"
```

and rerun the script (`bash createSampleSheet.sh`). Then the sample.tsv should be created successfully. 
(The additional fastq part in the renaming is added to avoid confusions with other potential '_1' parts
in the fie name)

In case you have several lanes for samples, you can concatenate them prior to creating the samples.tsv
script with the script `concatenateFiles.sh`which is in the pipeline folder `workflow/scripts`. Currently, you would need to run the script inside the same folder where the fastq files are located.

# Next steps

The pipeline is now properly configured and you can move on.

Continue with running the pipeline: [Usage](https://github.com/fischuu/Pipeline-Holoruminant-Meta/blob/main/docs/04-Usage.md)
