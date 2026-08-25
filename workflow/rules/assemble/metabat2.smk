rule assemble__metabat2__run:
    """Run metabat2 end-to-end on a single assembly"""
    input:
        alignments=get_alignments_from_assembly_id,
        crais=get_alignment_indexes_from_assembly_id,
        assembly=lambda wildcards: (
            MEGAHIT / f"{wildcards.assembly_id}.fa.gz" if config["assembler"] == "megahit" else 
            METASPADES / f"{wildcards.assembly_id}.fa.gz"if config["assembler"] == "metaspades" else 
            PROVIDED / f"{wildcards.assembly_id}.fa.gz"
        ),
    output:
        bins=directory(METABAT2 / "{assembly_id}"),
    log:
        METABAT2 / "{assembly_id}.log",
    benchmark:
        METABAT2 / "benchmark/{assembly_id}.tsv",
    container:
        docker["assemble"]
    params:
        bins_prefix=lambda w: METABAT2 / f"{w.assembly_id}/bin",
        bams=compose_bams_for_metabat2_run,
        depth=lambda w: METABAT2 / f"{w.assembly_id}.depth",
        paired=lambda w: METABAT2 / f"{w.assembly_id}.paired",
        workdir=METABAT2,
        minLen=params["assemble"]["metabat"]["min_contig_len"],
    threads: esc("cpus", "assemble__metabat2__run")
    resources:
        runtime=esc("runtime", "assemble__metabat2__run"),
        mem_mb=esc("mem_mb", "assemble__metabat2__run"),
        cpus_per_task=esc("cpus", "assemble__metabat2__run"),
        slurm_partition=esc("partition", "assemble__metabat2__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__metabat2__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__metabat2__run"))
    shell:
        """
        exec > {log} 2>&1

        echo "== converting alignments to mapped-only BAM =="
        for aln in {input.alignments}; do
            sample=$(basename "$aln")
            sample=${{sample%.cram}}
            sample=${{sample%.bam}}
            samtools view \
                --exclude-flags 4 \
                --fast \
                --output-fmt BAM \
                --threads {threads} \
                --output "{params.workdir}/${{sample}}.bam" \
                "$aln"
        done

        echo "== summarizing per-contig depth across all libraries =="
        jgi_summarize_bam_contig_depths \
            --outputDepth {params.depth} \
            --pairedContigs {params.paired} \
            {params.bams}

        echo "== binning with MetaBAT2 =="
        metabat2 \
            --inFile {input.assembly} \
            --abdFile {params.depth} \
            --outFile {params.bins_prefix} \
            --numThreads {threads} \
            --minContig {params.minLen} \
            --verbose

        rm --force --verbose {params.bams} {params.depth} {params.paired}

        find {output.bins} -name "*.fa" -exec pigz --best --verbose {{}} +
        """


rule assemble__metabat2:
    """Run metabat2 over all assemblies"""
    input:
        [METABAT2 / assembly_id for assembly_id in ASSEMBLIES],
