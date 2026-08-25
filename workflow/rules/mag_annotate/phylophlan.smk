rule mag_annotate__phylophlan:
    """
    Run phylophlan for the dereplicated genomes
    """
    input:
        DREP / "dereplicated_genomes",
    output:
        folder=directory(PHYLOPHLAN / "SGB"),
        result= PHYLOPHLAN / "SGB" / "SGB.tsv",
    log:
        PHYLOPHLAN / "phylophlan_sgb.log",
    benchmark:
        PHYLOPHLAN / "benchmark/phylophlan_sgb.tsv",
    threads: esc("cpus", "mag_annotate__phylophlan")
    resources:
        runtime=esc("runtime", "mag_annotate__phylophlan"),
        mem_mb=esc("mem_mb", "mag_annotate__phylophlan"),
        cpus_per_task=esc("cpus", "mag_annotate__phylophlan"),
        slurm_partition=esc("partition", "mag_annotate__phylophlan"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__phylophlan')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("mag_annotate__phylophlan"))
    container:
        docker["mag_annotate"]
    params:
        result= PHYLOPHLAN / "SGB" / "SGB",
    shell:
        # NOTE: the SGB release name and database folder are hardcoded rather
        # than read from config/features.yaml's "phylophlan" entries, which
        # only cover the (unused by this rule) amphora2/phylophlan databases.
        # If the SGB database location ever changes, update it here.
        """
            echo Running Phylophlan on $(hostname) 2>> {log} 1>&2

            mkdir -p {output.folder}

            phylophlan_assign_sgbs -i {input} \
                                   -d SGB.Jun23 \
                                   --database_folder resources/databases/phylophlan/ \
                                   -e fa.gz \
                                   -o {params.result} \
                                   --nproc {threads} \
                                   --verbose \
                                   --overwrite \
                                   2>> {log} 1>&2

      """
