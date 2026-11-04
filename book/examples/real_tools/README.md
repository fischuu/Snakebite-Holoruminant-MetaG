# Real tools on a computer with only Docker

These scripts run the pipeline's real rules, with the real tools in their real containers, on a computer that has
Docker but no Apptainer and no cluster. Part IV of the book quotes the results.

- `shim/singularity` stands in for Apptainer and starts the commands with Docker.
- `prepare.sh` makes a project with a small cut of the example reads, the genome of PhiX as a stand-in for a host, and the
  databases small enough for a laptop.
- `run.sh` runs targets in that project, one job at a time.
- `show_results.sh` records what the book quotes into `../transcripts/real_tools.txt`.
- `small_demos.sh` runs FastQC, Kraken2 and Krona by hand on a part of the reads, and records that into `../transcripts/real_tools_small_demos.txt`.

To use them, you need the subsets from the example archive, see `tests/real_run/README.md`:

    export SNAKEMAKE=/path/to/snakemake PYTHON=/path/to/python
    bash prepare.sh <folder with the subsets> <project folder> 1000000
    bash run.sh <project folder> preprocess assemble

For speed and space, `prepare.sh` lets the steps that only need `ln`, `bgzip`, `fastqc` and `samtools` share images
that are there anyway. On an x86-64 computer they'd run natively. On an ARM computer they run under emulation, which took
about 2 hours for the steps up to the binners, and which may crash some tools, as it did for SingleM and MetaPhlAn.
