rule assemble__metabat2__run:
    """Bin the contigs of one assembly with MetaBAT2, using each contig's depth in each library"""
    input:
        contigs=CONTIGS,
        alignments=assembly_alignments,
        indexes=assembly_alignment_indexes,
    output:
        directory(METABAT2 / "{assembly_id}"),
    log:
        METABAT2 / "{assembly_id}.log",
    benchmark:
        METABAT2 / "benchmark/{assembly_id}.tsv",
    container:
        docker["assemble"]
    params:
        min_contig=params["assemble"]["metabat"]["min_contig_len"],
    threads: esc("cpus", "assemble__metabat2__run")
    resources:
        runtime=esc("runtime", "assemble__metabat2__run"),
        mem_mb=esc("mem_mb", "assemble__metabat2__run"),
        cpus_per_task=esc("cpus", "assemble__metabat2__run"),
        slurm_partition=esc("partition", "assemble__metabat2__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__metabat2__run')['nvme']}",
        attempt=esc("attempt", "assemble__metabat2__run"),
    shell:
        """
        exec > {log} 2>&1
        depth={METABAT2}/{wildcards.assembly_id}.depth
        pairs={METABAT2}/{wildcards.assembly_id}.paired
        debug "assembly_id={wildcards.assembly_id} threads={threads} min_contig={params.min_contig} depth=$depth"

        bams=()
        for alignment in {input.alignments}; do
            bam="{METABAT2}/$(basename "${{alignment%.*}}").bam"
            samtools view -b -1 -F 4 -@ {threads} -o "$bam" "$alignment"
            bams+=("$bam")
        done

        jgi_summarize_bam_contig_depths --outputDepth "$depth" --pairedContigs "$pairs" "${{bams[@]}}"

        metabat2 -i {input.contigs} -a "$depth" -o {output}/bin \
            -m {params.min_contig} -t {threads} -v

        rm -f "${{bams[@]}}" "$depth" "$pairs"
        find {output} -name "*.fa" -exec pigz -9 {{}} +
        """


rule assemble__metabat2:
    """Run MetaBAT2 for every assembly"""
    input:
        expand(METABAT2 / "{assembly_id}", assembly_id=ASSEMBLIES),
