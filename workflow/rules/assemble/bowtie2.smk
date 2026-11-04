# {assembly_id}.{sample_id}.{library_id}: one library mapped against one assembly
_LIBRARY_ON_ASSEMBLY = "{assembly_id}.{sample_id}.{library_id}"


rule assemble__bowtie2__build__run:
    """Index the contigs of one assembly for read mapping"""
    input:
        CONTIGS,
    output:
        index=touch(ASSEMBLY_INDEX / "{assembly_id}"),
    log:
        ASSEMBLY_INDEX / "{assembly_id}.log",
    benchmark:
        ASSEMBLY_INDEX / "benchmark/{assembly_id}.tsv"
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__bowtie2__build__run")
    resources:
        runtime=esc("runtime", "assemble__bowtie2__build__run"),
        mem_mb=esc("mem_mb", "assemble__bowtie2__build__run"),
        cpus_per_task=esc("cpus", "assemble__bowtie2__build__run"),
        slurm_partition=esc("partition", "assemble__bowtie2__build__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__bowtie2__build__run')['nvme']}",
        attempt=esc("attempt", "assemble__bowtie2__build__run"),
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec > "$try_log" 2>&1
        debug "assembly_id={wildcards.assembly_id} threads={threads} contigs={input}"
        bowtie2-build --threads {threads} {input} {output.index}
        mv "$try_log" {log}
        """


rule assemble__bowtie2__build:
    """Index every assembly"""
    input:
        expand(ASSEMBLY_INDEX / "{assembly_id}", assembly_id=ASSEMBLIES),


rule assemble__bowtie2__map:
    """Map one library against one assembly and sort it into the configured format"""
    input:
        index=ASSEMBLY_INDEX / "{assembly_id}",
        contigs=CONTIGS,
        forward_=CLEAN_FORWARD,
        reverse_=CLEAN_REVERSE,
    output:
        alignment=ASSEMBLY_MAPPING / f"{_LIBRARY_ON_ASSEMBLY}.{ALIGN_EXT}",
        unsorted=temp(ASSEMBLY_MAPPING / f"{_LIBRARY_ON_ASSEMBLY}.tmp.bam"),
    log:
        ASSEMBLY_MAPPING / f"{_LIBRARY_ON_ASSEMBLY}.log",
    benchmark:
        ASSEMBLY_MAPPING / f"benchmark/{_LIBRARY_ON_ASSEMBLY}.tsv"
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__bowtie2__map")
    resources:
        runtime=esc("runtime", "assemble__bowtie2__map"),
        mem_mb=esc("mem_mb", "assemble__bowtie2__map"),
        cpus_per_task=esc("cpus", "assemble__bowtie2__map"),
        slurm_partition=esc("partition", "assemble__bowtie2__map"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__bowtie2__map')['nvme']}",
        attempt=esc("attempt", "assemble__bowtie2__map"),
    params:
        sort_memory=params["assemble"]["samtools"]["mem"],
        rg_id=compose_rg_id,
        rg_extra=compose_rg_extra,
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec > "$try_log" 2>&1
        debug "threads={threads} contigs={input.contigs} rg_id={params.rg_id} format={SAMTOOLS_OUTTYPE} sort_memory={params.sort_memory}"

        bowtie2 --threads {threads} --rg-id '{params.rg_id}' --rg '{params.rg_extra}' \
                -x {input.index} -1 {input.forward_} -2 {input.reverse_} \
            | samtools view -b -o {output.unsorted} -

        samtools sort -@ {threads} -m {params.sort_memory} -l 9 -O {SAMTOOLS_OUTTYPE} \
            -o {output.alignment} {output.unsorted}

        mv "$try_log" {log}
        """


rule assemble__bowtie2:
    """Map every library against every assembly it belongs to"""
    input:
        [
            ASSEMBLY_MAPPING / f"{assembly_id}.{sample_id}.{library_id}.{ALIGN_EXT}"
            for assembly_id, sample_id, library_id in ASSEMBLY_LIBRARIES
        ],
