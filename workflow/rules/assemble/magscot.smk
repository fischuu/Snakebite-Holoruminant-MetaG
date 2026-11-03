# MAGScoT scores the bins of all binners by marker genes and refines them. The steps up to its run
# follow the MAGScoT manual (workflow/scripts/MAGScoT/README.md). Everything of one assembly stays
# in this folder:
_MAGSCOT_RUN = MAGSCOT / "{assembly_id}"


rule assemble__magscot__prodigal:
    """Predict the proteins of one assembly, with one prodigal per FASTA chunk"""
    input:
        CONTIGS,
    output:
        _MAGSCOT_RUN / "prodigal.faa",
    log:
        _MAGSCOT_RUN / "prodigal.log",
    benchmark:
        _MAGSCOT_RUN / "benchmark_prodigal.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__magscot__prodigal")
    resources:
        runtime=esc("runtime", "assemble__magscot__prodigal"),
        mem_mb=esc("mem_mb", "assemble__magscot__prodigal"),
        cpus_per_task=esc("cpus", "assemble__magscot__prodigal"),
        slurm_partition=esc("partition", "assemble__magscot__prodigal"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__prodigal')['nvme']}",
        attempt=esc("attempt", "assemble__magscot__prodigal"),
    retries: len(get_escalation_order("assemble__magscot__prodigal"))
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec 2> "$try_log"
        debug "assembly_id={wildcards.assembly_id} threads={threads} contigs={input} proteins={output}"

        # GNU parallel keeps control files in $TMPDIR. On this cluster the inherited value (and
        # config tmp_storage, which resolves to the same) is a per-job path of the real host /tmp,
        # which the container cannot see, because its /tmp is bind-mounted to the project's tmp/
        # folder (see --singularity-args in the run script). So use an own folder in the
        # container's /tmp, unique per job as that folder is shared by all running jobs. A killed
        # job leaves it behind.
        TMPDIR="/tmp/magscot_prodigal.{wildcards.assembly_id}.{resources.attempt}.$$"
        export TMPDIR
        mkdir -p "$TMPDIR"
        debug "TMPDIR=$TMPDIR"

        zcat {input} \
            | parallel -j {threads} --block 1M --recstart '>' --pipe --keep-order \
                prodigal -p meta -a /dev/stdout -d /dev/null -o /dev/null \
            > {output}

        rm -rf "$TMPDIR"
        mv "$try_log" {log}
        """


rule assemble__magscot__hmmsearch:
    """Search the proteins of one assembly against one marker gene set of MAGScoT (Pfam or TIGRFAM)"""
    input:
        proteins=_MAGSCOT_RUN / "prodigal.faa",
        hmm=lambda wildcards: features["magscot"][f"{wildcards.marker_set}_hmm"],
    output:
        hits=_MAGSCOT_RUN / "{marker_set}.tblout.gz",
    log:
        _MAGSCOT_RUN / "{marker_set}.log",
    benchmark:
        _MAGSCOT_RUN / "benchmark_hmmsearch_{marker_set}.tsv",
    wildcard_constraints:
        marker_set="pfam|tigr",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__magscot__hmmsearch")
    resources:
        runtime=esc("runtime", "assemble__magscot__hmmsearch"),
        mem_mb=esc("mem_mb", "assemble__magscot__hmmsearch"),
        cpus_per_task=esc("cpus", "assemble__magscot__hmmsearch"),
        slurm_partition=esc("partition", "assemble__magscot__hmmsearch"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__hmmsearch')['nvme']}",
        attempt=esc("attempt", "assemble__magscot__hmmsearch"),
    retries: len(get_escalation_order("assemble__magscot__hmmsearch"))
    shell:
        """
        exec > {log} 2>&1
        hits={output.hits}
        debug "assembly_id={wildcards.assembly_id} marker_set={wildcards.marker_set} threads={threads} hmm={input.hmm}"

        hmmsearch -o /dev/null --tblout "${{hits%.gz}}" --noali --notextw --cut_nc --cpu {threads} \
            {input.hmm} {input.proteins}
        pigz -9 -f -p {threads} "${{hits%.gz}}"
        """


rule assemble__magscot__marker_table:
    """Write the marker gene hits in MAGScoT's format: protein, marker, e-value"""
    input:
        tigr=_MAGSCOT_RUN / "tigr.tblout.gz",
        pfam=_MAGSCOT_RUN / "pfam.tblout.gz",
    output:
        _MAGSCOT_RUN / "hmm.tblout",
    log:
        _MAGSCOT_RUN / "hmm.log",
    benchmark:
        _MAGSCOT_RUN / "benchmark_join_hmms.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__magscot__marker_table")
    resources:
        runtime=esc("runtime", "assemble__magscot__marker_table"),
        mem_mb=esc("mem_mb", "assemble__magscot__marker_table"),
        cpus_per_task=esc("cpus", "assemble__magscot__marker_table"),
        slurm_partition=esc("partition", "assemble__magscot__marker_table"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__marker_table')['nvme']}",
        attempt=esc("attempt", "assemble__magscot__marker_table"),
    retries: len(get_escalation_order("assemble__magscot__marker_table"))
    shell:
        """
        exec > {log} 2>&1
        debug "tigr={input.tigr} pfam={input.pfam} table={output}"

        # A set without hits is a file of comments only, which is fine: awk skips them. TIGRFAM names
        # the marker in column 3, Pfam in column 4.
        {{
            zcat {input.tigr} | awk -v OFS='\t' '!/^#/ {{ print $1, $3, $5 }}'
            zcat {input.pfam} | awk -v OFS='\t' '!/^#/ {{ print $1, $4, $5 }}'
        }} > {output}
        """


rule assemble__magscot__merge_contig_to_bin:
    """List the contigs of every bin of the three binners: bin, contig, binner"""
    input:
        concoct=CONCOCT / "{assembly_id}",
        maxbin2=MAXBIN2 / "{assembly_id}",
        metabat2=METABAT2 / "{assembly_id}",
    output:
        _MAGSCOT_RUN / "contigs_to_bin.tsv",
    log:
        _MAGSCOT_RUN / "contigs_to_bin.log",
    benchmark:
        _MAGSCOT_RUN / "benchmark_merge_contig_to_bin.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__magscot__merge_contig_to_bin")
    resources:
        runtime=esc("runtime", "assemble__magscot__merge_contig_to_bin"),
        mem_mb=esc("mem_mb", "assemble__magscot__merge_contig_to_bin"),
        cpus_per_task=esc("cpus", "assemble__magscot__merge_contig_to_bin"),
        slurm_partition=esc("partition", "assemble__magscot__merge_contig_to_bin"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__merge_contig_to_bin')['nvme']}",
        attempt=esc("attempt", "assemble__magscot__merge_contig_to_bin"),
    retries: len(get_escalation_order("assemble__magscot__merge_contig_to_bin"))
    shell:
        """
        exec > {log} 2>&1
        debug "assembly_id={wildcards.assembly_id} table={output}"

        bins_of() {{
            find "$2" -type f -name "*.fa.gz" | while read -r bin; do
                zcat "$bin" | awk -v bin="bin_$(basename "$bin")" -v binner="$1" -v OFS='\t' \
                    'sub(/^>/, "") {{ print bin, $1, binner }}'
            done
        }}

        {{
            bins_of concoct {input.concoct}
            bins_of maxbin2 {input.maxbin2}
            bins_of metabat2 {input.metabat2}
        }} > {output}
        """


rule assemble__magscot__run:
    """Score and refine the bins of one assembly with MAGScoT

    A poor assembly can leave MAGScoT without any viable bin, which it reports by failing. That is
    no reason to stop the pipeline, so the rule carries on with empty tables in that case.
    """
    input:
        contigs_to_bin=_MAGSCOT_RUN / "contigs_to_bin.tsv",
        markers=_MAGSCOT_RUN / "hmm.tblout",
    output:
        _MAGSCOT_RUN / "magscot.gtdb_rel207_ar53.out",
        _MAGSCOT_RUN / "magscot.gtdb_rel207_bac120.out",
        _MAGSCOT_RUN / "magscot.refined.contig_to_bin.out",
        _MAGSCOT_RUN / "magscot.refined.out",
        _MAGSCOT_RUN / "magscot.scores.out",
    log:
        _MAGSCOT_RUN / "magscot.log",
    benchmark:
        _MAGSCOT_RUN / "benchmark_run.tsv",
    container:
        docker["assemble"]
    params:
        prefix=lambda w: MAGSCOT / w.assembly_id / "magscot",
        settings=params["assemble"]["magscot"],
        script_folder=SCRIPT_FOLDER,
    threads: esc("cpus", "assemble__magscot__run")
    resources:
        runtime=esc("runtime", "assemble__magscot__run"),
        mem_mb=esc("mem_mb", "assemble__magscot__run"),
        cpus_per_task=esc("cpus", "assemble__magscot__run"),
        slurm_partition=esc("partition", "assemble__magscot__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__run')['nvme']}",
        attempt=esc("attempt", "assemble__magscot__run"),
    retries: len(get_escalation_order("assemble__magscot__run"))
    shell:
        """
        exec > {log} 2>&1
        debug "assembly_id={wildcards.assembly_id} settings={params.settings}"

        Rscript --vanilla {params.script_folder}/MAGScoT/MAGScoT.R -i {input.contigs_to_bin} \
            --hmm {input.markers} -o {params.prefix} -t {params.settings[threshold]} \
            {params.settings[extra]} \
            || echo "MAGScoT failed, most likely no viable bins: continuing without bins"

        touch {output}
        """


rule assemble__magscot__label_contigs:
    """Write the refined bin into the contig ids, keeping only the contigs that are in a bin"""
    input:
        contigs=CONTIGS,
        refined=_MAGSCOT_RUN / "magscot.refined.contig_to_bin.out",
    output:
        table=_MAGSCOT_RUN / "magscot.reformat.tsv",
        binned_contigs=MAGSCOT / "{assembly_id}.fa.gz",
    log:
        _MAGSCOT_RUN / "magscot.rename.log",
    benchmark:
        _MAGSCOT_RUN / "benchmark_rename.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__magscot__label_contigs")
    resources:
        runtime=esc("runtime", "assemble__magscot__label_contigs"),
        mem_mb=esc("mem_mb", "assemble__magscot__label_contigs"),
        cpus_per_task=esc("cpus", "assemble__magscot__label_contigs"),
        slurm_partition=esc("partition", "assemble__magscot__label_contigs"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__magscot__label_contigs')['nvme']}",
        attempt=esc("attempt", "assemble__magscot__label_contigs"),
    retries: len(get_escalation_order("assemble__magscot__label_contigs"))
    params:
        script_folder=SCRIPT_FOLDER,
    shell:
        """
        exec 2> {log}
        debug "assembly_id={wildcards.assembly_id} refined={input.refined} binned_contigs={output.binned_contigs}"
        python {params.script_folder}/label_binned_contigs.py {input.refined} {output.table} <(zcat {input.contigs}) \
            | pigz -9 > {output.binned_contigs}
        """


rule assemble__magscot:
    """Run MAGScoT for every assembly"""
    input:
        expand(MAGSCOT / "{assembly_id}.fa.gz", assembly_id=ASSEMBLIES),
