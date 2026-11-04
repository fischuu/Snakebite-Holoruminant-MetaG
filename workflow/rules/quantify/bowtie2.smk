rule quantify__bowtie2__build:
    """Index the MAG catalogue for read mapping"""
    input:
        MAG_CATALOGUE,
    output:
        index=touch(MAG_INDEX / "dereplicated_genomes"),
    log:
        MAG_INDEX / "dereplicated_genomes.log",
    benchmark:
        MAG_INDEX / "benchmark/dereplicated_genomes.tsv",
    container:
        docker["bowtie2"]
    threads: esc("cpus", "quantify__bowtie2__build")
    resources:
        runtime=esc("runtime", "quantify__bowtie2__build"),
        mem_mb=esc("mem_mb", "quantify__bowtie2__build"),
        cpus_per_task=esc("cpus", "quantify__bowtie2__build"),
        slurm_partition=esc("partition", "quantify__bowtie2__build"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__bowtie2__build')['nvme']}",
        attempt=esc("attempt", "quantify__bowtie2__build"),
    shell:
        """
        exec 2> {log}
        debug "threads={threads} catalogue={input} index={output.index}"
        bowtie2-build --threads {threads} {input} {output.index}
        """


rule quantify__bowtie2__map:
    """Map one library against the MAG catalogue"""
    input:
        index=MAG_INDEX / "dereplicated_genomes",
        forward_=CLEAN_FORWARD,
        reverse_=CLEAN_REVERSE,
        catalogue=MAG_CATALOGUE,
        fai=MAG_CATALOGUE_FAI,
    output:
        MAG_CRAM,
    log:
        MAG_MAPPING / f"{LIBRARY}.log",
    benchmark:
        MAG_MAPPING / f"benchmark/{LIBRARY}.tsv",
    container:
        docker["bowtie2"]
    threads: esc("cpus", "quantify__bowtie2__map")
    resources:
        runtime=esc("runtime", "quantify__bowtie2__map"),
        mem_mb=esc("mem_mb", "quantify__bowtie2__map"),
        cpus_per_task=esc("cpus", "quantify__bowtie2__map"),
        slurm_partition=esc("partition", "quantify__bowtie2__map"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__bowtie2__map')['nvme']}",
        attempt=esc("attempt", "quantify__bowtie2__map"),
    params:
        sort_memory=params["quantify"]["samtools"]["mem"],
        rg_id=compose_rg_id,
        rg_extra=compose_rg_extra,
    shell:
        """
        exec > {log} 2>&1
        debug "library={wildcards.sample_id}.{wildcards.library_id} threads={threads} rg_id={params.rg_id} sort_memory={params.sort_memory} cram={output}"

        # samtools sort leaves "*.tmp.NNNN.bam" spill files behind when a previous attempt was killed
        find "$(dirname {output})" -name "$(basename {output}).tmp.*.bam" -delete

        bowtie2 --threads {threads} --rg-id '{params.rg_id}' --rg '{params.rg_extra}' \
                -x {input.index} -1 {input.forward_} -2 {input.reverse_} \
            | samtools sort -@ {threads} -m {params.sort_memory} -l 9 -M --reference {input.catalogue} \
                -o {output} -
        """


rule quantify__bowtie2:
    """Map every library against the MAG catalogue"""
    input:
        [
            MAG_MAPPING / f"{sample_id}.{library_id}.cram"
            for sample_id, library_id in SAMPLE_LIBRARY
        ],
