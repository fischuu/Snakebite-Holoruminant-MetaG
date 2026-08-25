rule assemble__bowtie2__build__run:
    """Build a bowtie2 index for one assembly"""
    input:
        contigs=lambda wildcards: (
            MEGAHIT / f"{wildcards.assembly_id}.fa.gz" if config["assembler"] == "megahit" else
            METASPADES / f"{wildcards.assembly_id}.fa.gz"if config["assembler"] == "metaspades" else
            PROVIDED / f"{wildcards.assembly_id}.fa.gz"
        )
    output:
        mock=touch(ASSEMBLE_INDEX / "{assembly_id}"),
    log:
        ASSEMBLE_INDEX / "{assembly_id}.log",
    benchmark:
        ASSEMBLE_INDEX / "benchmark/{assembly_id}.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__bowtie2__build")
    resources:
        runtime=esc("runtime", "assemble__bowtie2__build"),
        mem_mb=esc("mem_mb", "assemble__bowtie2__build"),
        cpus_per_task=esc("cpus", "assemble__bowtie2__build"),
        slurm_partition=esc("partition", "assemble__bowtie2__build"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__bowtie2__build')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__bowtie2__build"))
    shell:
        """
        exec > {log}.{resources.attempt} 2>&1
        bowtie2-build --threads {threads} {input.contigs} {output.mock}
        mv {log}.{resources.attempt} {log}
        """


rule assemble__bowtie2__build:
    """Build a bowtie2 index for every assembly"""
    input:
        [ASSEMBLE_INDEX / f"{assembly_id}" for assembly_id in ASSEMBLIES],

# Whether downstream alignments are stored as BAM or CRAM; ALIGN_EXT is read
# by assemble/__functions__.smk and assemble/concoct.smk as well.
SAMTOOLS_OUTTYPE = params["assemble"]["samtools"]["out_type"].upper()
assert SAMTOOLS_OUTTYPE in {"BAM", "CRAM"}, "params['assemble']['samtools']['out_type'] must be BAM or CRAM"
ALIGN_EXT = "cram" if SAMTOOLS_OUTTYPE == "CRAM" else "bam"


rule assemble__bowtie2__map:
    """Map one sample/library against one assembly, sorted into the configured BAM/CRAM output"""
    input:
        mock=ASSEMBLE_INDEX / "{assembly_id}",
        forward_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_1.fq.gz",
        reverse_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_2.fq.gz",
        reference=lambda wc: (
            MEGAHIT / f"{wc.assembly_id}.fa.gz" if config["assembler"] == "megahit" else
            METASPADES / f"{wc.assembly_id}.fa.gz" if config["assembler"] == "metaspades" else
            PROVIDED / f"{wc.assembly_id}.fa.gz"
        ),
    output:
        file=Path(str(ASSEMBLE_BOWTIE2 / "{assembly_id}.{sample_id}.{library_id}.") + ALIGN_EXT),
        tmp_bam=temp(ASSEMBLE_BOWTIE2 / "{assembly_id}.{sample_id}.{library_id}.tmp.bam"),
    log:
        log=ASSEMBLE_BOWTIE2 / "{assembly_id}.{sample_id}.{library_id}.log",
    benchmark:
        ASSEMBLE_BOWTIE2 / "benchmark/{assembly_id}.{sample_id}.{library_id}.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__bowtie2__map")
    resources:
        runtime=esc("runtime", "assemble__bowtie2__map"),
        mem_mb=esc("mem_mb", "assemble__bowtie2__map"),
        cpus_per_task=esc("cpus", "assemble__bowtie2__map"),
        slurm_partition=esc("partition", "assemble__bowtie2__map"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__bowtie2__map')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__bowtie2__map"))
    params:
        samtools_mem=params["assemble"]["samtools"]["mem"],
        samtools_outtype=params["assemble"]["samtools"]["out_type"].upper(),
        rg_id=compose_rg_id,
        rg_extra=compose_rg_extra,
    shell:
        """
        exec > {log}.{resources.attempt} 2>&1
        echo "[{wildcards.assembly_id}] mapping {wildcards.sample_id}.{wildcards.library_id}"

        bowtie2 -x {input.mock} -1 {input.forward_} -2 {input.reverse_} \
                --threads {threads} --rg-id '{params.rg_id}' --rg '{params.rg_extra}' \
            | samtools view --bam --output {output.tmp_bam} -

        samtools sort \
            -l 9 \
            -m {params.samtools_mem} \
            -O {params.samtools_outtype} \
            --threads {threads} \
            -o {output.file} \
            {output.tmp_bam}

        mv {log}.{resources.attempt} {log}
        """


rule assemble__bowtie2:
    """Map every sample to every assembly it belongs to"""
    input:
        [
            ASSEMBLE_BOWTIE2 / f"{assembly_id}.{sample_id}.{library_id}.cram"
            for assembly_id, sample_id, library_id in ASSEMBLY_SAMPLE_LIBRARY
        ],
