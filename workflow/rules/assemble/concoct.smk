rule assemble__concoct__run:
    """Bin one assembly's contigs with CONCOCT"""
    input:
        assembly=lambda wildcards: (
            MEGAHIT / f"{wildcards.assembly_id}.fa.gz" if config["assembler"] == "megahit" else 
            METASPADES / f"{wildcards.assembly_id}.fa.gz"if config["assembler"] == "metaspades" else 
            PROVIDED / f"{wildcards.assembly_id}.fa.gz"
        ),
        alignments=get_alignments_from_assembly_id,
    output:
        directory(CONCOCT / "{assembly_id}"),
    log:
        CONCOCT / "{assembly_id}.log",
    benchmark:
        CONCOCT / "benchmark/{assembly_id}.tsv",
    container:
        docker["concoct"]
    threads: esc("cpus", "assemble__concoct__run")
    resources:
        runtime=esc("runtime", "assemble__concoct__run"),
        mem_mb=esc("mem_mb", "assemble__concoct__run"),
        cpus_per_task=esc("cpus", "assemble__concoct__run"),
        slurm_partition=esc("partition", "assemble__concoct__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__concoct__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__concoct__run"))
    params:
        workdir=lambda w: CONCOCT / w.assembly_id,
    shell:
        """
        exec > {log} 2>&1
        mkdir --parents --verbose {params.workdir}

        echo "== cutting contigs into overlapping chunks =="
        cut_up_fasta.py \
            <(zcat {input.assembly}) \
            --chunk_size 10000 \
            --overlap_size 0 \
            --merge_last \
            --bedfile {params.workdir}/cut.bed \
        > {params.workdir}/cut.fa

        echo "== converting alignments to indexed, mapped-only BAM =="
        bams=()
        for aln in {input.alignments}; do
            sample=$(basename "$aln" ".{ALIGN_EXT}")
            bam={params.workdir}/${{sample}}.bam
            samtools view \
                --exclude-flags 4 \
                --fast \
                --output-fmt BAM \
                --threads {threads} \
                --output "$bam" \
                "$aln"
            samtools index "$bam"
            bams+=("$bam")
        done

        echo "== building coverage table and running CONCOCT =="
        concoct_coverage_table.py {params.workdir}/cut.bed "${{bams[@]}}" > {params.workdir}/coverage.tsv

        concoct \
            --threads {threads} \
            --composition_file {params.workdir}/cut.fa \
            --coverage_file {params.workdir}/coverage.tsv \
            --basename {params.workdir}/run

        echo "== merging cut-up clusters back to original contigs =="
        merge_cutup_clustering.py {params.workdir}/run_clustering_gt1000.csv > {params.workdir}/merge.csv

        extract_fasta_bins.py \
            <(zcat {input.assembly}) \
            {params.workdir}/merge.csv \
            --output_path {params.workdir}

        echo "== cleaning up intermediates =="
        rm --force --verbose \
            {params.workdir}/cut.fa {params.workdir}/cut.bed {params.workdir}/coverage.tsv \
            {params.workdir}/*.csv {params.workdir}/*.bam {params.workdir}/*.bai {params.workdir}/*.txt

        pigz --best --verbose {params.workdir}/*.fa
        """


rule assemble__concoct:
    """Run concoct on all assemblies"""
    input:
        [CONCOCT / f"{assembly_id}" for assembly_id in ASSEMBLIES],
