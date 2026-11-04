rule assemble__metaspades__run:
    """Assemble the pooled libraries of one assembly_id with metaSPAdes and give the contigs pipeline ids

    metaSPAdes takes a single library per run in meta mode, hence the pooling. The eukaryote module
    reads the assembly graph back from the archive of the working folder.
    """
    input:
        forwards=assembly_reads(1),
        reverses=assembly_reads(2),
    output:
        contigs=METASPADES / "{assembly_id}.fa.gz",
        workdir_archive=METASPADES / "{assembly_id}.tar.gz",
        pooled_forward=temp(METASPADES / "{assembly_id}_R1_concat.fastq.gz"),
        pooled_reverse=temp(METASPADES / "{assembly_id}_R2_concat.fastq.gz"),
    log:
        METASPADES / "{assembly_id}.log",
    benchmark:
        METASPADES / "benchmark/{assembly_id}.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__metaspades__run")
    resources:
        runtime=esc("runtime", "assemble__metaspades__run"),
        mem_mb=esc("mem_mb", "assemble__metaspades__run"),
        cpus_per_task=esc("cpus", "assemble__metaspades__run"),
        slurm_partition=esc("partition", "assemble__metaspades__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__metaspades__run')['nvme']}",
        attempt=esc("attempt", "assemble__metaspades__run"),
        metaspades_slots=1,
    params:
        workdir=lambda w: METASPADES / w.assembly_id,
        settings=params["assemble"]["metaspades"],
        script_folder=SCRIPT_FOLDER,
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec > "$try_log" 2>&1
        debug "assembly_id={wildcards.assembly_id} threads={threads} mem_mb={resources.mem_mb} settings={params.settings}"

        cat {input.forwards} > {output.pooled_forward}
        cat {input.reverses} > {output.pooled_reverse}

        metaspades.py -1 {output.pooled_forward} -2 {output.pooled_reverse} -o {params.workdir} \
            -t {threads} -m {resources.mem_mb} -k {params.settings[kmer_size]} \
            {params.settings[additional_options]}

        python {params.script_folder}/contig_ids.py {wildcards.assembly_id} {params.workdir}/contigs.fasta \
            | bgzip -l 9 -@ {threads} > {output.contigs}

        tar -cv -I "pigz -9 -p {threads}" --remove-files -f {output.workdir_archive} {params.workdir}

        mv "$try_log" {log}
        """


rule assemble__metaspades:
    """Run metaSPAdes for every assembly"""
    input:
        expand(METASPADES / "{assembly_id}.fa.gz", assembly_id=ASSEMBLIES),
