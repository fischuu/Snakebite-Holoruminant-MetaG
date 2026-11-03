rule preprocess__bowtie2__build:
    """Index one host genome for read mapping"""
    input:
        genome=HOST_FASTA,
        fai=HOST_FAI,
    output:
        index=touch(HOST_INDEX / "{genome}"),
    log:
        HOST_INDEX / "{genome}.log",
    benchmark:
        HOST_INDEX / "benchmark/{genome}.tsv",
    container:
        docker["bowtie2"]
    threads: esc("cpus", "preprocess__bowtie2__build")
    resources:
        runtime=esc("runtime", "preprocess__bowtie2__build"),
        mem_mb=esc("mem_mb", "preprocess__bowtie2__build"),
        cpus_per_task=esc("cpus", "preprocess__bowtie2__build"),
        slurm_partition=esc("partition", "preprocess__bowtie2__build"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'preprocess__bowtie2__build')['nvme']}",
        attempt=esc("attempt", "preprocess__bowtie2__build"),
    retries: len(get_escalation_order("preprocess__bowtie2__build"))
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec > "$try_log" 2>&1
        debug "genome={wildcards.genome} threads={threads}"
        bowtie2-build --threads {threads} {input.genome} {output.index}
        mv "$try_log" {log}
        """


rule preprocess__bowtie2__map:
    """Map one library against one host genome, as one step of the decontamination chain"""
    input:
        forward_=reads_for_host_mapping(1),
        reverse_=reads_for_host_mapping(2),
        index=HOST_INDEX / "{genome}",
        genome=HOST_FASTA,
        fai=HOST_FAI,
    output:
        cram=temp(HOST_CRAM),
        counts=HOST_COUNTS / "{genome}" / f"{LIBRARY}.chr_alignment_counts.tsv",
    log:
        HOST_MAPPING / "{genome}" / f"{LIBRARY}.log",
    benchmark:
        HOST_MAPPING / "benchmark/{genome}" / f"{LIBRARY}.tsv",
    params:
        sort_memory=params["preprocess"]["bowtie2"]["samtools"]["mem_per_thread"],
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
        attempt=esc("attempt", "preprocess__bowtie2__map"),
    retries: len(get_escalation_order("preprocess__bowtie2__map"))
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec > "$try_log" 2>&1
        debug "library={wildcards.sample_id}.{wildcards.library_id} genome={wildcards.genome} threads={threads} sort_memory={params.sort_memory}"

        # samtools sort leaves "*.tmp.NNNN.bam" spill files behind when a previous attempt was killed
        find "$(dirname {output.cram})" -name "$(basename {output.cram}).tmp.*.bam" -delete

        debug "forward={input.forward_} reverse={input.reverse_} cram={output.cram}"
        bowtie2 --threads {threads} --rg-id '{params.rg_id}' --rg '{params.rg_extra}' \
                -x {input.index} -1 {input.forward_} -2 {input.reverse_} \
            | samtools sort -@ {threads} -m {params.sort_memory} -l 9 -M --reference {input.genome} \
                -o {output.cram} -

        samtools idxstats {output.cram} | awk '{{print $1, $3}}' > {output.counts}

        mv "$try_log" {log}
        """


rule preprocess__bowtie2__extract_nonhost__run:
    """Write the read pairs with neither mate on this host genome to FASTQ, for the next step of the chain"""
    input:
        cram=HOST_CRAM,
        genome=HOST_FASTA,
        fai=HOST_FAI,
    output:
        forward_=temp(HOST_MAPPING / "non{genome}" / f"{LIBRARY}_1.fq.gz"),
        reverse_=temp(HOST_MAPPING / "non{genome}" / f"{LIBRARY}_2.fq.gz"),
    log:
        HOST_MAPPING / "non{genome}" / f"{LIBRARY}.log",
    benchmark:
        HOST_MAPPING / "benchmark/non{genome}" / f"{LIBRARY}.tsv",
    container:
        docker["bowtie2"]
    params:
        sort_tmpdir=lambda wc: f"./samtools_sort_tmp/{wc.sample_id}.{wc.library_id}",
    threads: esc("cpus", "preprocess__bowtie2__extract_nonhost__run")
    resources:
        runtime=esc("runtime", "preprocess__bowtie2__extract_nonhost__run"),
        mem_mb=esc("mem_mb", "preprocess__bowtie2__extract_nonhost__run"),
        cpus_per_task=esc("cpus", "preprocess__bowtie2__extract_nonhost__run"),
        slurm_partition=esc("partition", "preprocess__bowtie2__extract_nonhost__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'preprocess__bowtie2__extract_nonhost__run')['nvme']}",
        attempt=esc("attempt", "preprocess__bowtie2__extract_nonhost__run"),
    retries: len(get_escalation_order("preprocess__bowtie2__extract_nonhost__run"))
    shell:
        """
        exec 2> {log}
        debug "library={wildcards.sample_id}.{wildcards.library_id} genome={wildcards.genome} threads={threads} cram={input.cram} sort_tmpdir={params.sort_tmpdir}"
        mkdir -p {params.sort_tmpdir}

        # -f 12: read unmapped and mate unmapped. samtools fastq needs the pairs sorted by name.
        samtools view -u -f 12 -T {input.genome} {input.cram} \
            | samtools sort -n -l 0 -m 500M -@ {threads} -T {params.sort_tmpdir} \
            | samtools fastq -N -0 /dev/null -c 9 -@ {threads} \
                -1 >(pigz -p {threads} > {output.forward_}) \
                -2 >(pigz -p {threads} > {output.reverse_})
        """


rule preprocess__store_final_fastq:
    """Copy the fully preprocessed reads (post-decontamination, or post-fastp if no hosts) to their final path"""
    input:
        forward_=reads_after_last_host(1),
        reverse_=reads_after_last_host(2),
    output:
        forward_=CLEAN_FORWARD,
        reverse_=CLEAN_REVERSE,
    log:
        CLEAN_READS / "log" / f"{LIBRARY}.log",
    benchmark:
        CLEAN_READS / "benchmark" / f"{LIBRARY}.tsv",
    container:
        docker["bowtie2"]
    threads: esc("cpus", "preprocess__store_final_fastq")
    resources:
        runtime=esc("runtime", "preprocess__store_final_fastq"),
        mem_mb=esc("mem_mb", "preprocess__store_final_fastq"),
        cpus_per_task=esc("cpus", "preprocess__store_final_fastq"),
        slurm_partition=esc("partition", "preprocess__store_final_fastq"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'preprocess__store_final_fastq')['nvme']}",
        attempt=esc("attempt", "preprocess__store_final_fastq"),
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
            CLEAN_READS / f"{sample_id}.{library_id}_{end}.fq.gz"
            for sample_id, library_id in SAMPLE_LIBRARY
            for end in (1, 2)
        ]


rule preprocess__bowtie2:
    """Run the full host-decontamination chain (index, map, extract, store) for every host"""
    input:
        rules.preprocess__bowtie2__extract_nonhost.input
