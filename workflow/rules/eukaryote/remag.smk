rule eukaryote__remag__filter:
    """Classify one assembly's contigs with REMAG's HyenaDNA eukaryote filter

    Columns: contig_id, length, prediction (eukaryote / non_eukaryote), eukaryote_prob,
    confidence, num_windows, resampled. Contigs shorter than min_contig_length are not in it.

    REMAG names its files after the input ({assembly_id}.fa.gz -> {assembly_id}.fa_*). The
    classification table is copied next to the other tools' tables; the REMAG folder is kept
    as is, because eukaryote__remag__bin resumes from it. If the classifier can't be loaded,
    or a batch fails, REMAG keeps those contigs as eukaryotic and only logs it; both are
    turned into failures here.
    """
    input:
        assembly=CONTIGS,
    output:
        tsv=EUK_REMAG / "{assembly_id}.tsv",
        filtered=EUK_REMAG
        / "{assembly_id}"
        / "{assembly_id}.fa_eukaryotic_filtered.fasta",
    log:
        EUK_REMAG / "{assembly_id}.filter.log",
    benchmark:
        EUK_REMAG / "benchmark/{assembly_id}.filter.tsv"
    container:
        docker["remag"]
    threads: esc("cpus", "eukaryote__remag__filter")
    resources:
        runtime=esc("runtime", "eukaryote__remag__filter"),
        mem_mb=esc("mem_mb", "eukaryote__remag__filter"),
        cpus_per_task=esc("cpus", "eukaryote__remag__filter"),
        slurm_partition=esc("partition", "eukaryote__remag__filter"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'eukaryote__remag__filter')['nvme']}",
        attempt=esc("attempt", "eukaryote__remag__filter"),
    params:
        out_dir=lambda w: EUK_REMAG / w.assembly_id,
        min_contig_length=params["eukaryote"]["remag"]["min_contig_length"],
        hyenadna_batch_size=params["eukaryote"]["remag"]["hyenadna_batch_size"],
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec > "$try_log" 2>&1
        debug "assembly_id={wildcards.assembly_id} threads={threads} assembly={input.assembly} out_dir={params.out_dir} min_contig_length={params.min_contig_length}"

        # Start from an empty folder: REMAG reuses whatever it finds there, and refuses to
        # (exits) if an earlier run used a different min_contig_length.
        rm -rf {params.out_dir}

        remag \
            --fasta {input.assembly} \
            --output {params.out_dir} \
            --filter-only \
            --min-contig-length {params.min_contig_length} \
            --hyenadna-batch-size {params.hyenadna_batch_size} \
            --threads {threads}

        # remag.log rotates at 10 MB into remag.<timestamp>.log, so check all of them.
        if grep -q -E "HyenaDNA classifier not found|Failed to initialize HyenaDNA classifier|Classification error for batch" {params.out_dir}/remag*.log; then
            echo "REMAG's HyenaDNA classifier did not classify every contig, see {params.out_dir}/remag*.log"
            exit 1
        fi

        cp {params.out_dir}/{wildcards.assembly_id}.fa_hyenadna_classification.tsv {output.tsv}

        mv "$try_log" {log}
        """


rule eukaryote__remag__bin:
    """Bin one assembly's eukaryotic contigs with REMAG

    Runs in eukaryote__remag__filter's folder, where REMAG finds its own filtered FASTA and
    skips classifying again. Skipped, with an empty bins folder and a header-only bins.csv,
    when the contigs called eukaryotic add up to less than min_bin_size: no bin could pass
    the size cutoff then, and REMAG exits with an error when it has (nearly) nothing to bin.
    """
    input:
        assembly=CONTIGS,
        tsv=EUK_REMAG / "{assembly_id}.tsv",
        filtered=EUK_REMAG
        / "{assembly_id}"
        / "{assembly_id}.fa_eukaryotic_filtered.fasta",
        alignments=assembly_alignments,
        indexes=assembly_alignment_indexes,
    output:
        bins=directory(EUK_REMAG / "{assembly_id}" / "bins"),
        assignments=EUK_REMAG / "{assembly_id}" / "bins.csv",
    log:
        EUK_REMAG / "{assembly_id}.bin.log",
    benchmark:
        EUK_REMAG / "benchmark/{assembly_id}.bin.tsv"
    container:
        docker["remag"]
    threads: esc("cpus", "eukaryote__remag__bin")
    resources:
        runtime=esc("runtime", "eukaryote__remag__bin"),
        mem_mb=esc("mem_mb", "eukaryote__remag__bin"),
        cpus_per_task=esc("cpus", "eukaryote__remag__bin"),
        slurm_partition=esc("partition", "eukaryote__remag__bin"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'eukaryote__remag__bin')['nvme']}",
        attempt=esc("attempt", "eukaryote__remag__bin"),
    params:
        out_dir=lambda w: EUK_REMAG / w.assembly_id,
        coverage=compose_coverage_args_for_remag,
        min_contig_length=params["eukaryote"]["remag"]["min_contig_length"],
        min_bin_size=params["eukaryote"]["remag"]["min_bin_size"],
        hyenadna_batch_size=params["eukaryote"]["remag"]["hyenadna_batch_size"],
        extra=params["eukaryote"]["remag"]["extra"],
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec > "$try_log" 2>&1
        debug "assembly_id={wildcards.assembly_id} threads={threads} out_dir={params.out_dir} min_bin_size={params.min_bin_size} coverage={params.coverage}"

        # Prints the eukaryotic total, and succeeds only if it is below min_bin_size.
        if awk -F '\\t' -v min_bp={params.min_bin_size} '
                NR > 1 && $3 == "eukaryote" {{ bp += $2 }}
                END {{ printf "%d bp classified eukaryotic\\n", bp; exit !(bp < min_bp) }}
            ' {input.tsv}; then
            echo "below min_bin_size ({params.min_bin_size} bp), no bin possible; skipping REMAG binning"
            mkdir -p {output.bins}
            echo "contig,cluster" > {output.assignments}
        else
            # Same --min-contig-length as the filter step, otherwise REMAG refuses to resume.
            remag \
                --fasta {input.assembly} \
                {params.coverage} \
                --output {params.out_dir} \
                --min-contig-length {params.min_contig_length} \
                --min-bin-size {params.min_bin_size} \
                --hyenadna-batch-size {params.hyenadna_batch_size} \
                --threads {threads} \
                {params.extra}
        fi

        mv "$try_log" {log}
        """


rule eukaryote__remag:
    """Run REMAG's eukaryote filter and binning on every assembly"""
    input:
        [EUK_REMAG / f"{assembly_id}.tsv" for assembly_id in ASSEMBLIES],
        [EUK_REMAG / f"{assembly_id}" / "bins.csv" for assembly_id in ASSEMBLIES],
