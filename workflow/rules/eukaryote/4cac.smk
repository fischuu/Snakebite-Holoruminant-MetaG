rule eukaryote__4cac__extract_graph:
    """Pull one assembly's contigs, contig paths and assembly graph out of the metaSPAdes tarball

    4CAC reads scaffolds.fasta and scaffolds.paths. The pipeline's contigs are metaSPAdes'
    contigs.fasta, and contigs.paths has the same format as scaffolds.paths, so both are
    extracted under the scaffold names: 4CAC then classifies exactly the contigs the rest of
    the pipeline uses.
    """
    input:
        tarball=METASPADES / "{assembly_id}.tar.gz",
    output:
        contigs=temp(EUK_4CAC / "{assembly_id}" / "scaffolds.fasta"),
        paths=temp(EUK_4CAC / "{assembly_id}" / "scaffolds.paths"),
        graph=temp(EUK_4CAC / "{assembly_id}" / "assembly_graph_with_scaffolds.gfa"),
    log:
        EUK_4CAC / "{assembly_id}.extract_graph.log",
    benchmark:
        EUK_4CAC / "benchmark/{assembly_id}.extract_graph.tsv"
    container:
        docker["assemble"]
    threads: esc("cpus", "eukaryote__4cac__extract_graph")
    resources:
        runtime=esc("runtime", "eukaryote__4cac__extract_graph"),
        mem_mb=esc("mem_mb", "eukaryote__4cac__extract_graph"),
        cpus_per_task=esc("cpus", "eukaryote__4cac__extract_graph"),
        slurm_partition=esc("partition", "eukaryote__4cac__extract_graph"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'eukaryote__4cac__extract_graph')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("eukaryote__4cac__extract_graph"))
    params:
        tmp_dir=lambda w: EUK_4CAC / w.assembly_id / "extract_tmp",
    shell:
        """
        exec > {log}.{resources.attempt} 2>&1
        debug "assembly_id={wildcards.assembly_id} tarball={input.tarball} tmp_dir={params.tmp_dir}"
        rm --recursive --force {params.tmp_dir}
        mkdir --parents {params.tmp_dir}

        # The tarball stores the metaSPAdes folder under the path it was created from
        # (results/assemble/metaspades/<assembly_id>/), hence the leading wildcard.
        tar \
            --extract \
            --file {input.tarball} \
            --use-compress-program=pigz \
            --directory {params.tmp_dir} \
            --wildcards \
            '*{wildcards.assembly_id}/contigs.fasta' \
            '*{wildcards.assembly_id}/contigs.paths' \
            '*{wildcards.assembly_id}/assembly_graph_with_scaffolds.gfa'

        mv "$(find {params.tmp_dir} -type f -name contigs.fasta)" {output.contigs}
        mv "$(find {params.tmp_dir} -type f -name contigs.paths)" {output.paths}
        mv "$(find {params.tmp_dir} -type f -name assembly_graph_with_scaffolds.gfa)" {output.graph}
        rm --recursive --force {params.tmp_dir}

        mv {log}.{resources.attempt} {log}
        """


rule eukaryote__4cac__run:
    """Classify one metaSPAdes assembly's contigs with 4CAC (XGBoost, refined on the assembly graph)

    Columns: contig_id (pipeline name), node_id (metaSPAdes name), class (phage, plasmid,
    prokarya, eukarya, uncertain), then the four XGBoost scores the graph step started from.
    """
    input:
        contigs=EUK_4CAC / "{assembly_id}" / "scaffolds.fasta",
        paths=EUK_4CAC / "{assembly_id}" / "scaffolds.paths",
        graph=EUK_4CAC / "{assembly_id}" / "assembly_graph_with_scaffolds.gfa",
    output:
        tsv=EUK_4CAC / "{assembly_id}.tsv",
    log:
        EUK_4CAC / "{assembly_id}.log",
    benchmark:
        EUK_4CAC / "benchmark/{assembly_id}.tsv"
    container:
        docker["4cac"]
    threads: esc("cpus", "eukaryote__4cac__run")
    resources:
        runtime=esc("runtime", "eukaryote__4cac__run"),
        mem_mb=esc("mem_mb", "eukaryote__4cac__run"),
        cpus_per_task=esc("cpus", "eukaryote__4cac__run"),
        slurm_partition=esc("partition", "eukaryote__4cac__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'eukaryote__4cac__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("eukaryote__4cac__run"))
    params:
        workdir=lambda w: EUK_4CAC / w.assembly_id,
        install_dir=params["eukaryote"]["4cac"]["install_dir"],
        phage=params["eukaryote"]["4cac"]["phage"],
        plasmid=params["eukaryote"]["4cac"]["plasmid"],
        script_folder=SCRIPT_FOLDER,
    shell:
        """
        exec > {log}.{resources.attempt} 2>&1
        debug "assembly_id={wildcards.assembly_id} threads={threads} workdir={params.workdir} install_dir={params.install_dir} phage={params.phage} plasmid={params.plasmid}"

        # classify_4CAC.py expects the XGBoost scores under this exact name in --classdir
        # (default: --asmdir), and builds its paths by plain string concatenation, hence
        # the trailing slashes.
        echo "== XGBoost classification =="
        python {params.install_dir}/classify_xgb.py \
            --fasta {input.contigs} \
            --outfile {params.workdir}/scaffolds.fasta.probs_xgb_4class.out \
            --num_processes {threads}

        echo "== graph-based refinement =="
        python {params.install_dir}/classify_4CAC.py \
            --assembler metaSPAdes \
            --asmdir {params.workdir}/ \
            --outdir {params.workdir}/ \
            --phage {params.phage} \
            --plasmid {params.plasmid}

        echo "== translating metaSPAdes node names to pipeline contig ids =="
        python {params.script_folder}/fourcac_to_contig_ids.py \
            --contigs {input.contigs} \
            --scores {params.workdir}/scaffolds.fasta.probs_xgb_4class.out \
            --classification {params.workdir}/4CAC_classification.fasta \
            --assembly-id {wildcards.assembly_id} \
            --output {output.tsv}

        rm --force \
            {params.workdir}/scaffolds.fasta.probs_xgb_4class.out \
            {params.workdir}/4CAC_classification.fasta

        mv {log}.{resources.attempt} {log}
        """


rule eukaryote__4cac:
    """Run 4CAC on every assembly (metaSPAdes assemblies only, see FOURCAC_SUPPORTED)"""
    input:
        [EUK_4CAC / f"{assembly_id}.tsv" for assembly_id in ASSEMBLIES] if FOURCAC_SUPPORTED else [],
