# Overview
This Snakemake pipeline dedicated to Metagenomic data analysis consists out of several modules that
cover a) read-based b) contig-based and c) MAG-based analyses as well as quantification, quality
checks and a reporting module (which is currently under development). Naturally, it runs seamlessly
on HPC systems and all required software tools are bundled in docker containers. Further, all required databases are pre-configured and ready to be downloaded from a
central place.

This makes it straight forward and as user-friendly as it can get.

The pipeline is organised in modules, which can run one-by-one. Further, the user can also choose to
run individual tools, giving full flexibility on how to use and run the pipeline.

![Flow diagram of the pipeline](https://github.com/fischuu/Snakebite-Holoruminant-MetaG/blob/main/flowchart/flowchart.png?raw=true)

