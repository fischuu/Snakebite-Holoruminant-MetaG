#!/usr/bin/env bash
# The container commands of the chapter on containers, recorded with Docker (needs Docker).
docker run --rm --platform linux/amd64 --entrypoint bash fischuu/hrp_bowtie2:0.1 -c '
    bowtie2 --version 2>&1 | head -1 | cut -c1-90
    samtools --version | head -1
    head -1 /etc/os-release
    which bowtie2 samtools
    ls /scratch' 2>&1
