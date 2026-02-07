rule assemble__metaspades__run:
    """Run MetaSPAdes over one sample, merging all libraries in the process"""
    input:
        forwards=get_forwards_from_assembly_id,
        reverses=get_reverses_from_assembly_id,
    output:
        fasta=METASPADES / "{assembly_id}.fa.gz",
        tarball=METASPADES / "{assembly_id}.tar.gz",
        concatenated_forwards=temp(METASPADES / "{assembly_id}_R1_concat.fastq.gz"),
        concatenated_reverses=temp(METASPADES / "{assembly_id}_R2_concat.fastq.gz"),
    log:
        log=METASPADES / "{assembly_id}.log",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__metaspades__run")
    resources:
        runtime=esc("runtime", "assemble__metaspades__run"),
        mem_mb=esc("mem_mb", "assemble__metaspades__run"),
        cpus_per_task=esc("cpus", "assemble__metaspades__run"),
        slurm_partition=esc("partition", "assemble__metaspades__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__metaspades__run')['nvme']}",
        attempt=get_attempt,
        metaspades_slots=1,
    retries: len(get_escalation_order("assemble__metaspades__run"))
    params:
        out_dir=lambda w: METASPADES / w.assembly_id,
        kmer_size=params["assemble"]["metaspades"]["kmer_size"],
        additional_options=params["assemble"]["metaspades"]["additional_options"],
        forwards=aggregate_forwards_for_metaspades,
        reverses=aggregate_reverses_for_metaspades,
        assembly_id=lambda w: w.assembly_id,
    shell:
        """
        # Concatenate forward reads into a single file
        cat {params.forwards} > {output.concatenated_forwards}
        
        # Concatenate reverse reads into a single file
        cat {params.reverses} > {output.concatenated_reverses}
        
        metaspades.py \
            -t {threads} \
            --memory {resources.mem_mb} \
            -k {params.kmer_size} \
            {params.additional_options} \
            -1 {output.concatenated_forwards} \
            -2 {output.concatenated_reverses} \
            -o {params.out_dir} \
        2> {log}.{resources.attempt} 1>&2

        ( seqtk seq \
            {params.out_dir}/contigs.fasta \
        | cut -f 1 -d " " \
        | paste - - \
        | awk \
            '{{printf(">{params.assembly_id}:bin_NA@contig_%08d\\n%s\\n", NR, $2)}}' \
        | bgzip \
            -l9 \
            -@ {threads} \
        > {output.fasta} \
        ) 2>> {log}.{resources.attempt}

        tar \
            --create \
            --file {output.tarball} \
            --remove-files \
            --use-compress-program="pigz --best --processes {threads}" \
            --verbose \
            {params.out_dir} \
        2>> {log}.{resources.attempt} 1>&2

        mv {log}.{resources.attempt} {log}
        """

rule assemble__metaspades:
    """Rename all assemblies contigs to avoid future collisions"""
    input:
        [METASPADES / f"{assembly_id}.fa.gz" for assembly_id in ASSEMBLIES],
