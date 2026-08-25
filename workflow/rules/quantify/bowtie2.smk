rule quantify__bowtie2__build:
    """Build a bowtie2 index for the dereplicated genome catalogue"""
    input:
        contigs=DREP / "dereplicated_genomes.fa.gz",
    output:
        mock=touch(QUANT_INDEX / "dereplicated_genomes"),
    log:
        QUANT_INDEX / "dereplicated_genomes.log",
    benchmark:
        QUANT_INDEX / "benchmark/dereplicated_genomes.tsv",
    container:
        docker["bowtie2"]
    threads: esc("cpus", "quantify__bowtie2__build")
    resources:
        runtime=esc("runtime", "quantify__bowtie2__build"),
        mem_mb=esc("mem_mb", "quantify__bowtie2__build"),
        cpus_per_task=esc("cpus", "quantify__bowtie2__build"),
        slurm_partition=esc("partition", "quantify__bowtie2__build"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__bowtie2__build')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("quantify__bowtie2__build"))
    shell:
        """
        exec 2> {log}
        bowtie2-build --threads {threads} {input.contigs} {output.mock}
        """


rule quantify__bowtie2__map:
    """Map one sample/library against the dereplicated genome catalogue"""
    input:
        mock=QUANT_INDEX / "dereplicated_genomes",
        forward_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_1.fq.gz",
        reverse_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_2.fq.gz",
        reference=DREP / "dereplicated_genomes.fa.gz",
        fai=DREP / "dereplicated_genomes.fa.gz.fai",
    output:
        cram=QUANT_BOWTIE2 / "{sample_id}.{library_id}.cram",
    log:
        QUANT_BOWTIE2 / "{sample_id}.{library_id}.log",
    benchmark:
        QUANT_BOWTIE2 / "benchmark/{sample_id}.{library_id}.tsv",
    container:
        docker["bowtie2"]
    threads: esc("cpus", "quantify__bowtie2__map")
    resources:
        runtime=esc("runtime", "quantify__bowtie2__map"),
        mem_mb=esc("mem_mb", "quantify__bowtie2__map"),
        cpus_per_task=esc("cpus", "quantify__bowtie2__map"),
        slurm_partition=esc("partition", "quantify__bowtie2__map"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__bowtie2__map')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("quantify__bowtie2__map"))
    params:
        samtools_mem=params["quantify"]["samtools"]["mem"],
        rg_id=compose_rg_id,
        rg_extra=compose_rg_extra,
    shell:
        """
        exec > {log} 2>&1

        # Clear any stale samtools-sort spill files from a killed prior attempt.
        find "$(dirname {output.cram})" -name "$(basename {output.cram}).tmp.*.bam" -delete

        bowtie2 -x {input.mock} -1 {input.forward_} -2 {input.reverse_} \
                --threads {threads} --rg-id '{params.rg_id}' --rg '{params.rg_extra}' \
            | samtools sort --reference {input.reference} -l 9 -M -m {params.samtools_mem} \
                --threads {threads} -o {output.cram} -
        """


rule quantify__bowtie2:
    """Map every sample to the dereplicated genome catalogue"""
    input:
        [
            QUANT_BOWTIE2 / f"{sample_id}.{library_id}.cram"
            for sample_id, library_id in SAMPLE_LIBRARY
        ],
