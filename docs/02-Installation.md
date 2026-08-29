# Requirements
The pipeline requires Snakemake version 9. Further, it is currently tested with the slurm executor and
as such this one is also required to be installed. 

In essence, it can also run with smaller Snakemake versions, but it might cause some troubles with the
slurm executor and the escalation part of the resource allocation, version >8.11 were also running successfully. 

Supports:
SLURM executor / local execution
docker/singularity/apptainer support

## Python dependencies
Starting from Snakemake 8 it is required to install an executor plugin to submit jobs to a queueing system of a
HPC system. Please ensure you have installed the corresponding Snakemake plugins installed in case you want
to submit your jobs to a queueing system

```
pip install snakemake-executor-plugin-cluster-generic
pip install snakemake-executor-plugin-slurm

```

Of course you can also install other, specific executor plugins, but this might need more adjustments to the
existing files.

Depending on your Python version, you need to install a Pandas version > 2.1, there were errors when newer
Python versions met older Pandas version. In case you run into obscure Pandas error, please make sure to
install a newer pandas, e.g.

```
pip install pandas==2.2.3
```

# Installation

You can install the pipeline by cloning this repository

The recommended setup is to have a dedicated pipeline folder (the cloned repository), that carries the
functionality and which should not require any changes. 

Then your project should have somewhere an own folder and the required configuration files are copied to it.
The steps to perform are

```
# Go to the folder, to where you would like to clone the pipeline, e.g. 
 cd /users/fischerd/git

# First, clone the pipeline into that folder
  git clone git@github.com:fischuu/Snakebite-Holoruminant-MetaG.git

# In case the previous steps fails with an error that contains
# git@github.com: Permission denied (publickey)
# it indicates that you do not have a ssh key exchanged with GitHub
# and you could clone the repository then instead like this
#
# git clone https://github.com/fischuu/Snakebite-Holoruminant-MetaG.git
  
# Setting ENV variable to get downstream code more generic (so, this is the
# directory to where you cloned the pipeline)
  cd Snakebite-Holoruminant-MetaG
  PIPELINEFOLDER=$(pwd)
  
# If previous doesn't work, you can set it also manually like for example this
  PIPELINEFOLDER="/users/fischerd/git/Snakebite-Holoruminant-MetaG"
```

Next, we setup a project folder in our scratch space of the HPC, here we will run the pipeline

```
# Go to the project space of your HPC, e.g. 
  cd /scratch/project_2009831

# Create a folder for the new project
  mkdir My_holor_project
  cd My_holor_project   
  
# For convenience, we set again a ENV variable, so that the code will be more generic
  PROJECTFOLDER=$(pwd)
  
# Or manually the same thing again, in case the $(pwd) did not work for you:  
  PROJECTFOLDER="/scratch/project_2009831/My_holor_project"
```

Then we need to download the pre-compiled databases and reference genomes.
Be prepared that this step will take some time (3 days, depending on your connection)
and disc space (3TB). In case you have quick, local nvme discs, it is advisable to
use them for unpacking the files, as this will significantly increase the speed.

```
# Change to the project folder and prepare folders
  cd $PROJECTFOLDER
  mkdir -p reads
  mkdir -p resources/databases
  mkdir -p resources/reference

# Download the various pre-prepared reference databases
  cd $PROJECTFOLDER/resources/databases
  wget https://a3s.fi/Holoruminant-data/2025.04.04.bakta.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.04.04.camper.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.04.04.checkm2.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.11.25.diamond.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.04.04.dram.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.04.04.eggnog.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.04.04.gtdbtk.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.04.04.humann.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.11.26.hyddb.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.04.04.kraken2.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.04.04.krona.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.04.04.metaphlan4.tar.gz
  wget https://a3s.fi/Holoruminant-data/2026.02.18.ncyc.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.11.25.phyloflash.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.04.04.phylophlan.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.04.04.singlem.tar.gz
  wget https://a3s.fi/Holoruminant-data/2025.04.04.sylph.tar.gz

  wget https://a3s.fi/eggnog7_annotator/eggnog7_20251223_master_search_table.tsv.gz
  wget https://a3s.fi/eggnog7_annotator/eggnog7_20251223_proteins.dmnd
  mkdir -p eggnog7
  mv eggnog7_20251223_master_search_table.tsv.gz eggnog7/
  mv eggnog7_20251223_proteins.dmnd eggnog7/

# Unpack all the databases
  tar -xvf 2025.04.04.bakta.tar.gz
  tar -xvf 2025.04.04.camper.tar.gz
  tar -xvf 2025.04.04.checkm2.tar.gz
  tar -xvf 2025.11.25.diamond.tar.gz
  tar -xvf 2025.04.04.dram.tar.gz
  tar -xvf 2025.04.04.eggnog.tar.gz
  tar -xvf 2025.04.04.gtdbtk.tar.gz  
  tar -xvf 2025.04.04.humann.tar.gz
  tar -xvf 2025.11.26.hyddb.tar.gz
  tar -xvf 2025.04.04.kraken2.tar.gz
  tar -xvf 2025.04.04.krona.tar.gz
  tar -xvf 2025.04.04.metaphlan4.tar.gz
  tar -xvf 2026.02.18.ncyc.tar.gz
  tar -xvf 2025.04.04.phylophlan.tar.gz
  tar -xvf 2025.11.25.phyloflash.tar.gz
  tar -xvf 2025.04.04.singlem.tar.gz
  tar -xvf 2025.04.04.sylph.tar.gz

# Get the reference genomes (relevant for Holoruminant) for host contamination removal
# Obviously, you can also use your own set of reference genomes here instead
  cd $PROJECTFOLDER/resources
  wget https://a3s.fi/Holoruminant-data/2025.04.04.reference.tar.gz
  tar -xvf 2025.04.04.reference.tar.gz

# For MAGScot are also dedicated files needed, which can be pulled in a similar way
  cd $PROJECTFOLDER/resources
  wget https://a3s.fi/Holoruminant-data/2025.04.04.MAGScoT.tar.gz
  tar -xvf 2025.04.04.MAGScoT.tar.gz

# Get the example read data
  cd $PROJECTFOLDER
  wget https://a3s.fi/Holoruminant-data/2025.11.25.reads.tar.gz
  tar -xvf 2025.11.25.reads.tar.gz
```

If you have downloaded the resources already for another project, you can share
the resources also to a new project, e.g. by creating a symbolic link

```
cd $PROJECTFOLDER
ln -s /work/users/fischerd/RESOURCES/resources .
```

(Of course you can also adjsut the paths to the databases in the config file, if you prefer this option)

Now we copy the configuration files from the pipeline folder to the project folder,
to adjust the configurations to the project specifics

```
cd $PIPELINEFOLDER
cp -r config $PROJECTFOLDER
cp -r run_Pipeline-Holoruminant-meta.sh $PROJECTFOLDER
```

The tar-balls were created with this command (here example for diamond and the reads)

```
tar -czf "$(date +%Y.%m.%d).diamond.tar.gz" -C resources/databases diamond
tar -czf "$(date +%Y.%m.%d).reads.tar.gz" reads
```

# Next steps

Now all files are in place and the pipeline is ready for setting it up.

Continue with preparing the configuration files: [Setup](https://github.com/fischuu/Snakebite-Holoruminant-MetaG/blob/main/docs/03-Setup.md)
