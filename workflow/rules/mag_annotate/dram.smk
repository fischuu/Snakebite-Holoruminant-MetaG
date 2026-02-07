rule mag_annotate__dram__annotate:
    """Annotate dereplicate genomes with DRAM"""
    input:
        dereplicated_genomes=DREP / "dereplicated_genomes.fa.gz",
        gtdbtk_summary=GTDBTK / "gtdbtk.summary.tsv",
        dram_db=features["databases"]["dram"],
    output:
        annotation=DRAM / "annotate" / "annotations.tsv",
        trnas=DRAM / "annotate" / "trnas.tsv",
        rrnas=DRAM / "annotate" / "rrnas.tsv",
        genes=DRAM / "annotate" / "genes.faa",
    log:
        DRAM / "annotate.log",
    container:
        docker["dram"]
    params:
        config=config["dram-config"],
        min_contig_size=1500,
        out_dir=DRAM,
        tmp_dir=DRAM / "annotate",
        parallel_retries=5,
    threads: esc("cpus", "mag_annotate__dram__annotate")
    resources:
        runtime=esc("runtime", "mag_annotate__dram__annotate"),
        mem_mb=esc("mem_mb", "mag_annotate__dram__annotate"),
        cpus_per_task=esc("cpus", "mag_annotate__dram__annotate"),
        slurm_partition=esc("partition", "mag_annotate__dram__annotate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__dram__annotate')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("mag_annotate__dram__annotate"))
    shell:
        """
        rm -rf {params.tmp_dir}
        
        echo "Hostname: $(hostname)" 2>> {log} 1>&2
        echo "Temporary directory: $TMPDIR" 2>> {log} 1>&2
        df -h 2>> {log} 1>&2
        
        DRAM.py annotate \
                --config_loc {params.config} \
                --input_fasta {input.dereplicated_genomes} \
                --output_dir {params.tmp_dir} \
                --threads {threads} \
                --gtdb_taxonomy {input.gtdbtk_summary} \
        2>> {log} 1>&2
        
        for f in annotations.tsv trnas.tsv rrnas.tsv; do
          if [ ! -f "{params.tmp_dir}/$f" ]; then
            echo "DRAM did not generate $f -> creating empty file" >> {log}
            touch "{params.tmp_dir}/$f"
          fi
        done

    """

rule mag_annotate__fix_dram_annotations_scaffold:
    input:
        DRAM / "annotate" / "annotations.tsv",
    output:
        DRAM / "annotate" / "annotations.fixed.tsv",
    log:
        DRAM / "fix_annotation.log",
    container:
        docker["assemble"]
    params:
        script_folder=SCRIPT_FOLDER,
    shell:
        """
        python {params.script_folder}/fix_annotations.py {input} {output} 2>> {log} 1>&2
        """

rule mag_annotate__dram__distill:
    """Distill DRAM annotations."""
    input:
        annotations=DRAM / "annotate" / "annotations.fixed.tsv",
        trnas=DRAM / "annotate" / "trnas.tsv",
        rrnas=DRAM / "annotate" / "rrnas.tsv",
        dram_db=features["databases"]["dram"],
    output:
        genome=DRAM / "genome_stats.tsv",
        metabolism=DRAM / "metabolism_summary.xlsx",
        product_html=DRAM / "product.html",
        product_tsv=DRAM / "product.tsv",
    log:
        DRAM / "distill.log2",
    container:
        docker["dram"]
    threads: esc("cpus", "mag_annotate__dram__distill")
    resources:
        runtime=esc("runtime", "mag_annotate__dram__distill"),
        mem_mb=esc("mem_mb", "mag_annotate__dram__distill"),
        cpus_per_task=esc("cpus", "mag_annotate__dram__distill"),
        slurm_partition=esc("partition", "mag_annotate__dram__distill"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__dram__distill')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("mag_annotate__dram__distill"))
    params:
        config=config["dram-config"],
        outdir_tmp=DRAM / "distill_tmp",
        outdir=DRAM,
    shell:
        """
        # This is maybe needed as snakemake creates the folders, but dram relies on creating it itself
        rm -rf {params.outdir_tmp} 2> {log} 1>&2
        
        DRAM.py distill \
            --config_loc {params.config} \
            --input_file {input.annotations} \
            --rrna_path {input.rrnas} \
            --trna_path {input.trnas} \
            --output_dir {params.outdir_tmp} \
        2>> {log} 1>&2

        mv {params.outdir_tmp}/* {params.outdir}/ 2>> {log} 1>&2
        rm -rf {params.outdir_tmp} 2>> {log} 1>&2
        """

rule mag_annotate__dram:
    """Run DRAM on dereplicated genomes."""
    input:
        rules.mag_annotate__dram__distill.output,
