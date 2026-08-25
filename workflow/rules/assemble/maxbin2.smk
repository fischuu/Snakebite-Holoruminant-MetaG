rule assemble__maxbin2__run:
    """Run MaxBin2 over a single assembly"""
    input:
        assembly=lambda wildcards: (
            MEGAHIT / f"{wildcards.assembly_id}.fa.gz" if config["assembler"] == "megahit" else 
            METASPADES / f"{wildcards.assembly_id}.fa.gz"if config["assembler"] == "metaspades" else 
            PROVIDED / f"{wildcards.assembly_id}.fa.gz"
        ),
        alignments=get_alignments_from_assembly_id,
    output:
        workdir=directory(MAXBIN2 / "{assembly_id}"),
    log:
        MAXBIN2 / "{assembly_id}.log",
    benchmark:
        MAXBIN2 / "benchmark/{assembly_id}.tsv",
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__maxbin2__run")
    resources:
        runtime=esc("runtime", "assemble__maxbin2__run"),
        mem_mb=esc("mem_mb", "assemble__maxbin2__run"),
        cpus_per_task=esc("cpus", "assemble__maxbin2__run"),
        slurm_partition=esc("partition", "assemble__maxbin2__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__maxbin2__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("assemble__maxbin2__run"))
    params:
        seed=1,
        coverage=lambda w: MAXBIN2 / f"{w.assembly_id}/maxbin2.coverage",
        minLen=params["assemble"]["maxbin"]["min_contig_len"],
    shell:
        """
        exec > {log} 2>&1
        mkdir --parents {output.workdir}

        echo "== deriving mean per-contig coverage for MaxBin2 =="
        samtools coverage {input.alignments} \
            | awk '!/^#/ {{print $1, $5}}' OFS='\t' \
            > {params.coverage}

        run_MaxBin.pl \
            -thread {threads} \
            -contig {input.assembly} \
            -out {output.workdir}/maxbin2 \
            -abund {params.coverage} \
            -min_contig_length {params.minLen}

        for fasta in {output.workdir}/*.fasta; do
            [ -e "$fasta" ] && mv "$fasta" "${{fasta%.fasta}}.fa"
        done

        find {output.workdir} -name "*.fa" -exec pigz --best --verbose {{}} +

        rm --recursive --force --verbose \
            {output.workdir}/maxbin.{{coverage,log,marker,noclass,summary,tooshort}} \
            {output.workdir}/maxbin2.marker_of_each_bin.tar.gz
        """


rule assemble__maxbin2:
    """Run MaxBin2 over all assemblies"""
    input:
        [MAXBIN2 / assembly_id for assembly_id in ASSEMBLIES],
