rule assemble__megahit__run:
    """Assemble one assembly_id's pooled libraries with MEGAHIT and rename its contigs

    megahit's --force flag is used since the output directory it writes to
    already exists (Snakemake creates it ahead of time for the log/benchmark
    paths), and megahit otherwise refuses to write into an existing folder.
    """
    input:
        forwards=get_forwards_from_assembly_id,
        reverses=get_reverses_from_assembly_id,
    output:
        fasta=MEGAHIT / "{assembly_id}.fa.gz",
        tarball=MEGAHIT / "{assembly_id}.tar.gz",
    log:
        log=MEGAHIT / "{assembly_id}.log",
    benchmark:
        MEGAHIT / "benchmark/{assembly_id}.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__megahit__run")
    resources:
        runtime=esc("runtime", "assemble__megahit__run"),
        mem_mb=esc("mem_mb", "assemble__megahit__run"),
        cpus_per_task=esc("cpus", "assemble__megahit__run"),
        slurm_partition=esc("partition", "assemble__megahit__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__megahit__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__megahit__run"))
    params:
        out_dir=lambda w: MEGAHIT / w.assembly_id,
        mincount=params["assemble"]["megahit"]["mincount"],
        kmin=params["assemble"]["megahit"]["kmin"],
        kmax=params["assemble"]["megahit"]["kmax"],
        kstep=params["assemble"]["megahit"]["kstep"],
        additional=params["assemble"]["megahit"]["additional_options"],
        min_contig_len=params["assemble"]["megahit"]["min_contig_len"],
        forwards=aggregate_forwards_for_megahit,
        reverses=aggregate_reverses_for_megahit,
        assembly_id=lambda w: w.assembly_id,
    shell:
        """
        exec > {log}.{resources.attempt} 2>&1

        echo "== assembling {params.assembly_id} =="
        megahit \
            --num-cpu-threads {threads} \
            --min-count {params.mincount} \
            --k-min {params.kmin} \
            --k-max {params.kmax} \
            --k-step {params.kstep} \
            --min-contig-len {params.min_contig_len} \
            --verbose \
            --force \
            --continue \
            --out-dir {params.out_dir} \
            {params.additional} \
            -1 {params.forwards} \
            -2 {params.reverses}

        echo "== renaming contigs to {params.assembly_id}:bin_NA@contig_######## =="
        seqtk seq {params.out_dir}/final.contigs.fa \
            | cut -d ' ' -f 1 \
            | paste - - \
            | awk -v assembly="{params.assembly_id}" \
                '{{ printf(">%s:bin_NA@contig_%08d\\n%s\\n", assembly, NR, $2) }}' \
            | bgzip --compress-level 9 --threads {threads} \
            > {output.fasta}

        tar \
            --create \
            --file {output.tarball} \
            --remove-files \
            --use-compress-program="pigz --best --processes {threads}" \
            --verbose \
            {params.out_dir}

        mv {log}.{resources.attempt} {log}
        """


rule assemble__megahit:
    """Rename all assemblies contigs to avoid future collisions"""
    input:
        [MEGAHIT / f"{assembly_id}.fa.gz" for assembly_id in ASSEMBLIES],
