rule eukaryote__tiara__run:
    """Classify one assembly's contigs with Tiara (prokaryote / eukaryote / organelle)

    Columns: sequence_id, class_fst_stage (archaea, bacteria, prokarya, eukarya, organelle,
    unknown), class_snd_stage (mitochondrion, plastid, unknown for organelles, n/a otherwise),
    then the per-class probabilities. Contigs shorter than min_len are not in the table.
    Tiara writes its class counts next to the table as log_<table name>.
    """
    input:
        assembly=get_assembly_fasta,
    output:
        tsv=EUK_TIARA / "{assembly_id}.tsv",
        summary=EUK_TIARA / "log_{assembly_id}.tsv",
    log:
        EUK_TIARA / "{assembly_id}.log",
    benchmark:
        EUK_TIARA / "benchmark/{assembly_id}.tsv"
    container:
        docker["tiara"]
    threads: esc("cpus", "eukaryote__tiara__run")
    resources:
        runtime=esc("runtime", "eukaryote__tiara__run"),
        mem_mb=esc("mem_mb", "eukaryote__tiara__run"),
        cpus_per_task=esc("cpus", "eukaryote__tiara__run"),
        slurm_partition=esc("partition", "eukaryote__tiara__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'eukaryote__tiara__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("eukaryote__tiara__run"))
    params:
        min_len=params["eukaryote"]["tiara"]["min_len"],
        prob_cutoff=params["eukaryote"]["tiara"]["prob_cutoff"],
    shell:
        """
        exec > {log}.{resources.attempt} 2>&1
        debug "assembly_id={wildcards.assembly_id} threads={threads} assembly={input.assembly} min_len={params.min_len} prob_cutoff={params.prob_cutoff}"

        tiara \
            --input {input.assembly} \
            --output {output.tsv} \
            --min_len {params.min_len} \
            --prob_cutoff {params.prob_cutoff} \
            --probabilities \
            --threads {threads}

        mv {log}.{resources.attempt} {log}
        """


rule eukaryote__tiara:
    """Run Tiara on every assembly"""
    input:
        [EUK_TIARA / f"{assembly_id}.tsv" for assembly_id in ASSEMBLIES],
