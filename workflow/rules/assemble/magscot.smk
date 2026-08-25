rule assemble__magscot__prodigal:
    """Predict genes on one assembly with prodigal, parallelized over FASTA chunks"""
    input:
        assembly=lambda wildcards: (
            MEGAHIT / f"{wildcards.assembly_id}.fa.gz" if config["assembler"] == "megahit" else
            METASPADES / f"{wildcards.assembly_id}.fa.gz"if config["assembler"] == "metaspades" else
            PROVIDED / f"{wildcards.assembly_id}.fa.gz"
        ),
    output:
        proteins=MAGSCOT / "{assembly_id}" / "prodigal.faa",
    log:
        MAGSCOT / "{assembly_id}" / "prodigal.log",
    benchmark:
        MAGSCOT / "{assembly_id}" / "benchmark_prodigal.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__magscot__prodigal")
    resources:
        runtime=esc("runtime", "assemble__magscot__prodigal"),
        mem_mb=esc("mem_mb", "assemble__magscot__prodigal"),
        cpus_per_task=esc("cpus", "assemble__magscot__prodigal"),
        slurm_partition=esc("partition", "assemble__magscot__prodigal"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__prodigal')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__magscot__prodigal"))
    shell:
        """
        exec 2> {log}.{resources.attempt}
        zcat {input.assembly} \
            | parallel --jobs {threads} --block 1M --recstart '>' --pipe --keep-order \
                prodigal -p meta -a /dev/stdout -d /dev/null -o /dev/null \
            > {output.proteins}
        mv {log}.{resources.attempt} {log}
        """


rule assemble__magscot__hmmsearch_pfam:
    """Search predicted proteins against Pfam with hmmsearch"""
    input:
        proteins=MAGSCOT / "{assembly_id}" / "prodigal.faa",
        hmm=features["magscot"]["pfam_hmm"],
    output:
        tblout=MAGSCOT / "{assembly_id}" / "pfam.tblout.gz",
    log:
        MAGSCOT / "{assembly_id}" / "pfam.log",
    benchmark:
        MAGSCOT / "{assembly_id}" / "benchmark_hmmsearch_pfam.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__magscot__hmmsearch_pfam")
    resources:
        runtime=esc("runtime", "assemble__magscot__hmmsearch_pfam"),
        mem_mb=esc("mem_mb", "assemble__magscot__hmmsearch_pfam"),
        cpus_per_task=esc("cpus", "assemble__magscot__hmmsearch_pfam"),
        slurm_partition=esc("partition", "assemble__magscot__hmmsearch_pfam"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__hmmsearch_pfam')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__magscot__hmmsearch_pfam"))
    shell:
        """
        exec > {log} 2>&1
        echo "[{wildcards.assembly_id}] hmmsearch vs Pfam"
        hmmsearch \
            -o /dev/null \
            --tblout >(pigz --best --processes {threads} > {output.tblout}) \
            --noali --notextw --cut_nc \
            --cpu {threads} \
            {input.hmm} {input.proteins}
        """


rule assemble__magscot__hmmsearch_tigr:
    """Search predicted proteins against TIGRFAM with hmmsearch"""
    input:
        proteins=MAGSCOT / "{assembly_id}" / "prodigal.faa",
        hmm=features["magscot"]["tigr_hmm"],
    output:
        tblout=MAGSCOT / "{assembly_id}" / "tigr.tblout.gz",
    log:
        MAGSCOT / "{assembly_id}" / "tigr.log",
    benchmark:
        MAGSCOT / "{assembly_id}" / "benchmark_hmmsearch_tigr.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__magscot__hmmsearch_tigr")
    resources:
        runtime=esc("runtime", "assemble__magscot__hmmsearch_tigr"),
        mem_mb=esc("mem_mb", "assemble__magscot__hmmsearch_tigr"),
        cpus_per_task=esc("cpus", "assemble__magscot__hmmsearch_tigr"),
        slurm_partition=esc("partition", "assemble__magscot__hmmsearch_tigr"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__hmmsearch_tigr')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__magscot__hmmsearch_tigr"))
    shell:
        """
        exec > {log} 2>&1
        echo "[{wildcards.assembly_id}] hmmsearch vs TIGRFAM"
        hmmsearch \
            -o /dev/null \
            --tblout >(pigz --best --processes {threads} > {output.tblout}) \
            --noali --notextw --cut_nc \
            --cpu {threads} \
            {input.hmm} {input.proteins}
        """


rule assemble__magscot__join_hmms:
    """Combine the Pfam and TIGRFAM hits into MAGScoT's expected 3-column format

    zgrep exits non-zero when a tblout has no hits (every line is a '#' comment);
    that's an expected outcome here, not an error, so it's deliberately ignored.
    """
    input:
        tigr_tblout=MAGSCOT / "{assembly_id}" / "tigr.tblout.gz",
        pfam_tblout=MAGSCOT / "{assembly_id}" / "pfam.tblout.gz",
    output:
        merged=MAGSCOT / "{assembly_id}" / "hmm.tblout",
    log:
        MAGSCOT / "{assembly_id}" / "hmm.log",
    benchmark:
        MAGSCOT / "{assembly_id}" / "benchmark_join_hmms.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__magscot__join_hmms")
    resources:
        runtime=esc("runtime", "assemble__magscot__join_hmms"),
        mem_mb=esc("mem_mb", "assemble__magscot__join_hmms"),
        cpus_per_task=esc("cpus", "assemble__magscot__join_hmms"),
        slurm_partition=esc("partition", "assemble__magscot__join_hmms"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__join_hmms')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__magscot__join_hmms"))
    shell:
        """
        exec > {log} 2>&1
        (zgrep -v '^#' {input.tigr_tblout} || true) | awk '{{print $1"\t"$3"\t"$5}}' >  {output.merged}
        (zgrep -v '^#' {input.pfam_tblout} || true) | awk '{{print $1"\t"$4"\t"$5}}' >> {output.merged}
        """


rule assemble__magscot__merge_contig_to_bin:
    """Combine CONCOCT/MaxBin2/MetaBAT2 bin assignments into one contig-to-bin table

    Output columns: BIN_ID <TAB> CONTIG_ID <TAB> METHOD
    """
    input:
        concoct=CONCOCT / "{assembly_id}",
        maxbin2=MAXBIN2 / "{assembly_id}",
        metabat2=METABAT2 / "{assembly_id}",
    output:
        MAGSCOT / "{assembly_id}" / "contigs_to_bin.tsv",
    log:
        MAGSCOT / "{assembly_id}" / "contigs_to_bin.log",
    benchmark:
        MAGSCOT / "{assembly_id}" / "benchmark_merge_contig_to_bin.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__magscot__merge_contig_to_bin")
    resources:
        runtime=esc("runtime", "assemble__magscot__merge_contig_to_bin"),
        mem_mb=esc("mem_mb", "assemble__magscot__merge_contig_to_bin"),
        cpus_per_task=esc("cpus", "assemble__magscot__merge_contig_to_bin"),
        slurm_partition=esc("partition", "assemble__magscot__merge_contig_to_bin"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__merge_contig_to_bin')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__magscot__merge_contig_to_bin"))
    shell:
        """
        exec > {log} 2>&1
        : > {output}
        for entry in "concoct:{input.concoct}" "maxbin2:{input.maxbin2}" "metabat2:{input.metabat2}"; do
            method=${{entry%%:*}}
            binner_dir=${{entry#*:}}
            for fa in $(find "$binner_dir" -name "*.fa.gz" -type f); do
                bin_id=$(basename "$fa" .fa)
                zgrep '^>' "$fa" | tr -d '>' \
                    | awk -v bin="$bin_id" -v method="$method" '{{ print "bin_" bin "\t" $1 "\t" method }}'
            done
        done >> {output}
        """


rule assemble__magscot__run:
    """Score and refine bins from the merged contig-to-bin table with MAGScoT

    MAGScoT can legitimately find no viable bins for a poor assembly; that run
    is allowed to fail without failing the pipeline, and the expected output
    files are touched into existence so downstream rules have something to read.
    """
    input:
        contigs_to_bin=MAGSCOT / "{assembly_id}" / "contigs_to_bin.tsv",
        hmm=MAGSCOT / "{assembly_id}" / "hmm.tblout",
    output:
        ar53=MAGSCOT / "{assembly_id}" / "magscot.gtdb_rel207_ar53.out",
        bac120=MAGSCOT / "{assembly_id}" / "magscot.gtdb_rel207_bac120.out",
        refined_contig_to_bin=MAGSCOT / "{assembly_id}" / "magscot.refined.contig_to_bin.out",
        refined_out=MAGSCOT / "{assembly_id}" / "magscot.refined.out",
        scores=MAGSCOT / "{assembly_id}" / "magscot.scores.out",
    log:
        MAGSCOT / "{assembly_id}/magscot.log",
    benchmark:
        MAGSCOT / "{assembly_id}" / "benchmark_run.tsv",
    container:
        docker["assemble"]
    params:
        out_prefix=lambda w: MAGSCOT / w.assembly_id / "magscot",
        extra=params["assemble"]["magscot"]["extra"],
        th=params["assemble"]["magscot"]["threshold"],
        script_folder=SCRIPT_FOLDER,
    threads: esc("cpus", "assemble__magscot__run")
    resources:
        runtime=esc("runtime", "assemble__magscot__run"),
        mem_mb=esc("mem_mb", "assemble__magscot__run"),
        cpus_per_task=esc("cpus", "assemble__magscot__run"),
        slurm_partition=esc("partition", "assemble__magscot__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__magscot__run"))
    shell:
        """
        Rscript --vanilla {params.script_folder}/MAGScoT/MAGScoT.R \
            --input {input.contigs_to_bin} \
            --hmm {input.hmm} \
            --out {params.out_prefix} \
            {params.extra} \
            --threshold {params.th} \
            > {log} 2>&1 || echo "MAGScoT exited non-zero (likely no bins produced); continuing" >> {log}

        touch {output.ar53} {output.bac120} {output.refined_contig_to_bin} {output.refined_out} {output.scores}
        echo "exit: $?" >> {log}
        """


rule assemble__magscot__reformat:
    """Convert MAGScoT's refined contig-to-bin table into the pipeline's bin-naming scheme"""
    input:
        refined_contig_to_bin=MAGSCOT / "{assembly_id}" / "magscot.refined.contig_to_bin.out",
    output:
        clean=MAGSCOT / "{assembly_id}" / "magscot.reformat.tsv",
    log:
        MAGSCOT / "{assembly_id}" / "magscot.reformat.log",
    benchmark:
        MAGSCOT / "{assembly_id}" / "benchmark_reformat.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__magscot__reformat")
    resources:
        runtime=esc("runtime", "assemble__magscot__reformat"),
        mem_mb=esc("mem_mb", "assemble__magscot__reformat"),
        cpus_per_task=esc("cpus", "assemble__magscot__reformat"),
        slurm_partition=esc("partition", "assemble__magscot__reformat"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__reformat')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__magscot__reformat"))
    params:
        script_folder=SCRIPT_FOLDER,
    shell:
        """
        if [ -s {input.refined_contig_to_bin} ]; then
            Rscript --vanilla {params.script_folder}/clean_magscot_bin_to_contig.R \
                --input-file {input.refined_contig_to_bin} \
                --output-file {output.clean} \
            > {log} 2>&1
        else
            echo "MAGScoT produced no bins for this assembly; writing an empty output" > {log}
            touch {output.clean}
        fi
        """


rule assemble__magscot__rename:
    """Rename assembly contigs to the pipeline's bin-aware header scheme, dropping unbinned contigs"""
    input:
        assembly=lambda wildcards: (
            MEGAHIT / f"{wildcards.assembly_id}.fa.gz" if config["assembler"] == "megahit" else
            METASPADES / f"{wildcards.assembly_id}.fa.gz"if config["assembler"] == "metaspades" else
            PROVIDED / f"{wildcards.assembly_id}.fa.gz"
        ),
        clean=MAGSCOT / "{assembly_id}" / "magscot.reformat.tsv",
    output:
        fasta=MAGSCOT / "{assembly_id}.fa.gz",
    log:
        MAGSCOT / "{assembly_id}" / "magscot.rename.log",
    benchmark:
        MAGSCOT / "{assembly_id}" / "benchmark_rename.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__magscot__rename")
    resources:
        runtime=esc("runtime", "assemble__magscot__rename"),
        mem_mb=esc("mem_mb", "assemble__magscot__rename"),
        cpus_per_task=esc("cpus", "assemble__magscot__rename"),
        slurm_partition=esc("partition", "assemble__magscot__rename"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__rename')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__magscot__rename"))
    params:
        script_folder=SCRIPT_FOLDER,
        empty_fasta=lambda wildcards: MAGSCOT / f"{wildcards.assembly_id}.fa",
    shell:
        """
        if [ -s {input.clean} ]; then
            python {params.script_folder}/reformat_fasta_magscot.py \
                <(zcat {input.assembly}) \
                {input.clean} \
            | pigz --best > {output.fasta} 2> {log}
        else
            echo "No bin mapping available; writing an empty assembly" > {log}
            touch {params.empty_fasta}
            gzip {params.empty_fasta}
        fi
        """


rule assemble__magscot:
    """Run MAGScoT bin refinement over every assembly"""
    input:
        [MAGSCOT / f"{assembly_id}.fa.gz" for assembly_id in ASSEMBLIES],
