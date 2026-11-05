rule assemble__maxbin2__run:
    """Bin the contigs of one assembly with MaxBin2, using one abundance value per contig"""
    input:
        contigs=CONTIGS,
        alignments=assembly_alignments,
    output:
        directory(MAXBIN2 / "{assembly_id}"),
    log:
        MAXBIN2 / "{assembly_id}.log",
    benchmark:
        MAXBIN2 / "benchmark/{assembly_id}.tsv"
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__maxbin2__run")
    resources:
        runtime=esc("runtime", "assemble__maxbin2__run"),
        mem_mb=esc("mem_mb", "assemble__maxbin2__run"),
        cpus_per_task=esc("cpus", "assemble__maxbin2__run"),
        slurm_partition=esc("partition", "assemble__maxbin2__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__maxbin2__run')['nvme']}",
        attempt=esc("attempt", "assemble__maxbin2__run"),
    params:
        min_contig=params["assemble"]["maxbin"]["min_contig_len"],
    shell:
        """
        exec > {log} 2>&1
        mkdir -p {output}
        debug "assembly_id={wildcards.assembly_id} threads={threads} min_contig={params.min_contig} bins={output}"

        # MaxBin2 asks for an abundance. That's the mean depth, column 7 of samtools coverage, and not column 5, which is
        # the number of covered bases, and so grows with the length of a contig.
        samtools coverage {input.alignments} | sed '/^#/d' | cut -f 1,7 > {output}/maxbin2.coverage

        run_MaxBin.pl -contig {input.contigs} -abund {output}/maxbin2.coverage -out {output}/maxbin2 \
            -min_contig_length {params.min_contig} -thread {threads}

        # The rest of the pipeline expects <bin>.fa.gz, and only the bins stay
        find {output} -name "*.fasta" | while read -r bin; do
            mv "$bin" "${{bin%.fasta}}.fa"
            pigz -9 "${{bin%.fasta}}.fa"
        done
        rm -rf {output}/maxbin2.{{coverage,log,marker,noclass,summary,tooshort}} \
            {output}/maxbin2.marker_of_each_bin.tar.gz
        """


rule assemble__maxbin2:
    """Run MaxBin2 for every assembly"""
    input:
        expand(MAXBIN2 / "{assembly_id}", assembly_id=ASSEMBLIES),
