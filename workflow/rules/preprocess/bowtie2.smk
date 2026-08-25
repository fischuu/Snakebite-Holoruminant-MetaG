rule preprocess__bowtie2__build:
    """Build a bowtie2 index for one host reference genome"""
    input:
        reference=HOSTS / "{genome}.fa.gz",
        faidx=HOSTS / "{genome}.fa.gz.fai",
    output:
        mock=touch(PRE_INDEX / "{genome}"),
    log:
        PRE_INDEX / "{genome}.log",
    benchmark:
        PRE_INDEX / "benchmark/{genome}.tsv",
    container:
        docker["bowtie2"]
    threads: esc("cpus", "preprocess__bowtie2__build")
    resources:
        runtime=esc("runtime", "preprocess__bowtie2__build"),
        mem_mb=esc("mem_mb", "preprocess__bowtie2__build"),
        cpus_per_task=esc("cpus", "preprocess__bowtie2__build"),
        slurm_partition=esc("partition", "preprocess__bowtie2__build"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'preprocess__bowtie2__build')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("preprocess__bowtie2__build"))
    shell:
        """
        exec > {log}.{resources.attempt} 2>&1
        bowtie2-build --threads {threads} {input.reference} {output.mock}
        mv {log}.{resources.attempt} {log}
        """


rule preprocess__bowtie2__map:
    """Map one library against one host genome (part of the sequential decontamination chain)"""
    input:
        forward_=get_input_forward_for_host_mapping,
        reverse_=get_input_reverse_for_host_mapping,
        mock=PRE_INDEX / "{genome}",
        reference=HOSTS / "{genome}.fa.gz",
        faidx=HOSTS / "{genome}.fa.gz.fai",
    output:
        cram=temp(PRE_BOWTIE2 / "{genome}" / "{sample_id}.{library_id}.cram"),
        counts=PRE_QUANT / "{genome}" / "{sample_id}.{library_id}.chr_alignment_counts.tsv"
    log:
        PRE_BOWTIE2 / "{genome}" / "{sample_id}.{library_id}.log",
    benchmark:
        PRE_BOWTIE2 / "benchmark/{genome}" / "{sample_id}.{library_id}.tsv"
    params:
        samtools_mem=params["preprocess"]["bowtie2"]["samtools"]["mem_per_thread"],
        rg_id=compose_rg_id,
        rg_extra=compose_rg_extra,
    container:
        docker["bowtie2"]
    threads: esc("cpus", "preprocess__bowtie2__map")
    resources:
        runtime=esc("runtime", "preprocess__bowtie2__map"),
        mem_mb=esc("mem_mb", "preprocess__bowtie2__map"),
        cpus_per_task=esc("cpus", "preprocess__bowtie2__map"),
        slurm_partition=esc("partition", "preprocess__bowtie2__map"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'preprocess__bowtie2__map')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("preprocess__bowtie2__map"))
    shell:
        """
        exec > {log}.{resources.attempt} 2>&1

        # samtools sort can leave "*.tmp.NNNN.bam" spill files behind from a
        # killed previous attempt; clear them before this attempt starts.
        find "$(dirname {output.cram})" -name "$(basename {output.cram}).tmp.*.bam" -delete

        bowtie2 -x {input.mock} -1 {input.forward_} -2 {input.reverse_} \
                --threads {threads} --rg-id '{params.rg_id}' --rg '{params.rg_extra}' \
            | samtools sort --reference {input.reference} -l 9 -M -m {params.samtools_mem} \
                --threads {threads} -o {output.cram} -

        samtools idxstats {output.cram} | awk '{{print $1, $3}}' > {output.counts}

        mv {log}.{resources.attempt} {log}
        """


rule preprocess__bowtie2__extract_nonhost__run:
    """Extract the read pairs where BOTH mates are unmapped (i.e. non-host) as FASTQ"""
    input:
        cram=PRE_BOWTIE2 / "{genome}" / "{sample_id}.{library_id}.cram",
        reference=HOSTS / "{genome}.fa.gz",
        fai=HOSTS / "{genome}.fa.gz.fai",
    output:
        forward_=temp(PRE_BOWTIE2 / "non{genome}" / "{sample_id}.{library_id}_1.fq.gz"),
        reverse_=temp(PRE_BOWTIE2 / "non{genome}" / "{sample_id}.{library_id}_2.fq.gz"),
    log:
        PRE_BOWTIE2 / "non{genome}" / "{sample_id}.{library_id}.log",
    benchmark:
        PRE_BOWTIE2 / "benchmark/non{genome}" / "{sample_id}.{library_id}.tsv"
    container:
        docker["bowtie2"]
    params:
        samtools_mem=params["preprocess"]["bowtie2"]["samtools"]["mem_per_thread"],
        sort_tmpdir=lambda wc: f"./samtools_sort_tmp/{wc.sample_id}.{wc.library_id}",
    threads: esc("cpus", "preprocess__bowtie2__extract_nonhost__run")
    resources:
        runtime=esc("runtime", "preprocess__bowtie2__extract_nonhost__run"),
        mem_mb=esc("mem_mb", "preprocess__bowtie2__extract_nonhost__run"),
        cpus_per_task=esc("cpus", "preprocess__bowtie2__extract_nonhost__run"),
        slurm_partition=esc("partition", "preprocess__bowtie2__extract_nonhost__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'preprocess__bowtie2__extract_nonhost__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("preprocess__bowtie2__extract_nonhost__run"))
    shell:
        """
        exec 2> {log}
        mkdir --parents {params.sort_tmpdir}

        samtools view --uncompressed -f 12 --reference {input.reference} {input.cram} \
            | samtools sort -n -l 0 -m 500M --threads {threads} -T {params.sort_tmpdir} \
            | samtools fastq -N -0 /dev/null -c 9 --threads {threads} \
                -1 >(pigz --processes {threads} > {output.forward_}) \
                -2 >(pigz --processes {threads} > {output.reverse_})
        """


rule preprocess__store_final_fastq:
    """Copy the fully preprocessed reads (post-decontamination, or post-fastp if no hosts) to their final path"""
    input:
        forward_=get_final_forward_from_pre,
        reverse_=get_final_reverse_from_pre,
    output:
        forward_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_1.fq.gz",
        reverse_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_2.fq.gz",
    log:
        PRE_BOWTIE2 / "decontaminated_reads" / "log" / "{sample_id}.{library_id}.log",
    benchmark:
        PRE_BOWTIE2 / "decontaminated_reads" / "benchmark" / "{sample_id}.{library_id}.tsv",
    container:
        docker["bowtie2"]
    threads: esc("cpus", "preprocess__store_final_fastq")
    resources:
        runtime=esc("runtime", "preprocess__store_final_fastq"),
        mem_mb=esc("mem_mb", "preprocess__store_final_fastq"),
        cpus_per_task=esc("cpus", "preprocess__store_final_fastq"),
        slurm_partition=esc("partition", "preprocess__store_final_fastq"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'preprocess__store_final_fastq')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("preprocess__store_final_fastq"))
    shell:
        """
        cp {input.forward_} {output.forward_}
        cp {input.reverse_} {output.reverse_}
        """


rule preprocess__bowtie2__extract_nonhost:
    """Store the final decontaminated FASTQs for every sample/library"""
    input:
        [
            PRE_BOWTIE2 / "decontaminated_reads" / f"{sample_id}.{library_id}_{end}.fq.gz"
            for sample_id, library_id in SAMPLE_LIBRARY
            for end in (1, 2)
        ]


rule preprocess__bowtie2:
    """Run the full host-decontamination chain (index, map, extract, store) for every host"""
    input:
        rules.preprocess__bowtie2__extract_nonhost.input
