# Overview

<img src="resources/logo.jpeg" alt="Logo" width="200" align="right"/>

This Snakemake pipeline dedicated to Metagenomic data analysis consists out of several modules that
cover a) read-based b) contig-based and c) MAG-based analyses as well as quantification, quality
checks and a reporting module (which is currently under development). Naturally, it runs seamlessly
on HPC systems and all required software tools are bundled in docker container and/or conda
environments. Further, all required databases are pre-configured and ready to be downloaded from a
central place.

This makes it straight forward and as user-friendly as it can get.

The pipeline is organised in modules, which can run one-by-one. Further, the user can also choose to
run individual tools, giving full flexibility on how to use and run the pipeline.

![Flow diagram of the pipeline](https://github.com/fischuu/Pipeline-Holoruminant-Meta/blob/main/flowchart/flowchart.png?raw=true)

# Installation, Setup and running the pipeline

For a step-by-step tutorial on how to install the pipeline and all pre-compiled databases, please see

Guide to install the pipeline: [Installation](https://github.com/fischuu/Pipeline-Holoruminant-Meta/blob/main/docs/02-Installation.md)

Guide to prepare the configuration files: [Setup](https://github.com/fischuu/Pipeline-Holoruminant-Meta/blob/main/docs/03-Setup.md)

Guide for running the pipeline: [Usage](https://github.com/fischuu/Pipeline-Holoruminant-Meta/blob/main/docs/04-Usage.md)

Information for additional tools: [Extra](https://github.com/fischuu/Pipeline-Holoruminant-Meta/blob/main/docs/05-Extra.md)

For troubleshooting, please visit the collection of most common errors: [Troubleshooting](https://github.com/fischuu/Pipeline-Holoruminant-Meta/blob/main/docs/10-Troubleshooting.md)


# Contributions

List of contributing authors:
...


# Contact
Please use the issue tracker from the GitHub or contact one of the contributors, if you'd prefer personal contact.


## References

- [`fastp`](https://github.com/OpenGene/fastp)
- [`kraken2`](https://github.com/DerrickWood/kraken2)
- [`SingleM`](https://github.com/wwood/singlem)
- [`Nonpareil`](https://github.com/lmrodriguezr/nonpareil)
- [`bowtie2`](https://github.com/BenLangmead/bowtie2)
- [`samtools`](https://github.com/samtools/samtools)
- [`MEGAHIT`](https://github.com/voutcn/megahit)
- [`CONCOCT`](https://github.com/BinPro/CONCOCT)
- [`MaxBin2`](http://downloads.jbei.org/data/microbial_communities/MaxBin/MaxBin.html)
- [`MetaBat2`](https://bitbucket.org/berkeleylab/metabat)
- [`MAGScoT`](https://github.com/ikmb/MAGScoT)
- [`dRep`](https://github.com/MrOlm/drep)
- [`QUAST`](https://github.com/ablab/quast)
- [`GTDB-TK`](https://github.com/Ecogenomics/GTDBTk)
- [`DRAM`](https://github.com/WrightonLabCSU/DRAM)
- [`CoverM`](https://github.com/wwood/CoverM)
- [`FastQC`](https://github.com/s-andrews/FastQC)
- [`multiqc`](https://github.com/ewels/MultiQC)
- [`NCyc`](https://github.com/qichao1984/NCyc)


# Acknowledgements
This pipeline is a fork from the Snakemake workflow

https://github.com/3d-omics/mg_assembly/

and tailored and extended to the needs of the Holoruminant project.
