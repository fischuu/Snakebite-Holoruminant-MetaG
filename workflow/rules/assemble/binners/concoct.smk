rule assemble__concoct__run:
    """Bin the contigs of one assembly with CONCOCT, following the steps of its manual"""
    input:
        contigs=CONTIGS,
        alignments=assembly_alignments,
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
        attempt=esc("attempt", "assemble__concoct__run"),
    retries: len(get_escalation_order("assemble__concoct__run"))
    shell:
        """
        exec > {log} 2>&1
        bins={output}
        mkdir -p "$bins"
        debug "assembly_id={wildcards.assembly_id} threads={threads} contigs={input.contigs} bins=$bins"

        echo "Cutting contigs into 10 kb pieces"
        cut_up_fasta.py <(zcat {input.contigs}) -c 10000 -o 0 --merge_last -b "$bins/contigs_10K.bed" \
            > "$bins/contigs_10K.fa"

        echo "Coverage of the pieces in each library, from its mapped reads"
        bams=()
        for alignment in {input.alignments}; do
            bam="$bins/$(basename "${{alignment%.*}}").bam"
            samtools view -b -1 -F 4 -@ {threads} -o "$bam" "$alignment"
            samtools index "$bam"
            bams+=("$bam")
        done
        debug "libraries=${{#bams[@]}}"
        concoct_coverage_table.py "$bins/contigs_10K.bed" "${{bams[@]}}" > "$bins/coverage_table.tsv"

        echo "Clustering"
        concoct --composition_file "$bins/contigs_10K.fa" --coverage_file "$bins/coverage_table.tsv" \
            -b "$bins/" --threads {threads}

        echo "Back from pieces to whole contigs"
        merge_cutup_clustering.py "$bins/clustering_gt1000.csv" > "$bins/clustering_merged.csv"
        extract_fasta_bins.py <(zcat {input.contigs}) "$bins/clustering_merged.csv" --output_path "$bins"

        # Only the bins stay
        rm -f "$bins"/contigs_10K.* "$bins"/coverage_table.tsv "$bins"/*.csv "$bins"/*.txt \
            "${{bams[@]}}" "$bins"/*.bai
        pigz -9 "$bins"/*.fa
        """


rule assemble__concoct:
    """Run CONCOCT for every assembly"""
    input:
        expand(CONCOCT / "{assembly_id}", assembly_id=ASSEMBLIES),
