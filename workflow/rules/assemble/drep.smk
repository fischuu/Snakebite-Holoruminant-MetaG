rule assemble__drep__separate_bins:
    """Split each assembly's renamed, binned FASTA into one file per bin"""
    input:
        assemblies=[MAGSCOT / f"{assembly_id}.fa.gz" for assembly_id in ASSEMBLIES],
    output:
        out_dir=directory(DREP / "separated_bins"),
    log:
        DREP / "separate_bins.log",
    benchmark:
        DREP / "benchmark/separate_bins.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__drep__separate_bins")
    resources:
        runtime=esc("runtime", "assemble__drep__separate_bins"),
        mem_mb=esc("mem_mb", "assemble__drep__separate_bins"),
        cpus_per_task=esc("cpus", "assemble__drep__separate_bins"),
        slurm_partition=esc("partition", "assemble__drep__separate_bins"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__drep__separate_bins')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__drep__separate_bins"))
    params:
        folder=config["pipeline_folder"],
    shell:
        """
        exec > {log} 2>&1
        {params.folder}/workflow/scripts/split_bins.sh {output.out_dir} {input.assemblies}
        """


rule assemble__drep__run:
    """Dereplicate all the bins using dRep."""
    input:
        genomes=DREP / "separated_bins",
    output:
        dereplicated_genomes=directory(DREP / "dereplicated_genomes"),
        data=DREP / "data.tar.gz",
        data_tables=DREP / "data_tables.tar.gz",
    log:
        DREP / "drep.log",
    benchmark:
        DREP / "benchmark/drep_run.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__drep__run")
    resources:
        runtime=esc("runtime", "assemble__drep__run"),
        mem_mb=esc("mem_mb", "assemble__drep__run"),
        cpus_per_task=esc("cpus", "assemble__drep__run"),
        slurm_partition=esc("partition", "assemble__drep__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__drep__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__drep__run"))
    params:
        out_dir=DREP,
        completeness=params["assemble"]["drep"]["completeness"],
        contamination=params["assemble"]["drep"]["contamination"],
        P_ani=params["assemble"]["drep"]["P_ani"],
        S_ani=params["assemble"]["drep"]["S_ani"],
        nc=params["assemble"]["drep"]["nc"],
        extra=params["assemble"]["drep"]["extra"]
    shell:
        """
        exec > {log}.{resources.attempt} 2>&1

        stale=(
            {params.out_dir}/data_tables {params.out_dir}/data
            {params.out_dir}/dereplicated_genomes {params.out_dir}/figures {params.out_dir}/log
        )
        rm --recursive --force -- "${{stale[@]}}"

        dRep dereplicate \
            {params.out_dir} \
            --processors {threads} \
            --completeness {params.completeness} \
            --contamination {params.contamination} \
            --P_ani {params.P_ani} \
            --S_ani {params.S_ani} \
            -nc {params.nc} \
            {params.extra} \
            --genomes {input.genomes}/*.fa

        for section in data data_tables; do
            tar \
                --create \
                --directory {params.out_dir} \
                --file {params.out_dir}/${{section}}.tar.gz \
                --remove-files \
                --use-compress-program="pigz --processes {threads}" \
                --verbose \
                ${{section}}
        done

        find {output.dereplicated_genomes} -type f ! -name "*.gz" -exec gzip {{}} +

        mv {log}.{resources.attempt} {log}
        """


rule assemble__drep__join_genomes:
    """Join all the dereplicated genomes into a single file."""
    input:
        DREP / "dereplicated_genomes",
    output:
        DREP / "dereplicated_genomes.fa.gz",
    log:
        DREP / "dereplicated_genomes.log",
    benchmark:
        DREP / "benchmark/join_genomes.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__drep__join_genomes")
    resources:
        runtime=esc("runtime", "assemble__drep__join_genomes"),
        mem_mb=esc("mem_mb", "assemble__drep__join_genomes"),
        cpus_per_task=esc("cpus", "assemble__drep__join_genomes"),
        slurm_partition=esc("partition", "assemble__drep__join_genomes"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__drep__join_genomes')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__drep__join_genomes"))
    shell:
        """
        exec 2> {log}
        zcat {input}/*.fa.gz | bgzip --compress-level 9 --threads {threads} > {output}
        """


rule assemble__drep:
    """Dereplicate all bins across every assembly into one genome catalogue with dRep"""
    input:
        DREP / "dereplicated_genomes.fa.gz",
