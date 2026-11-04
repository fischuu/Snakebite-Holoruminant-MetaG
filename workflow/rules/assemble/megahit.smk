rule assemble__megahit__run:
    """Assemble the libraries of one assembly_id with MEGAHIT and give the contigs pipeline ids

    --force because Snakemake has already created the output folder, which MEGAHIT otherwise
    refuses to write into.
    """
    input:
        forwards=assembly_reads(1),
        reverses=assembly_reads(2),
    output:
        contigs=MEGAHIT / "{assembly_id}.fa.gz",
        workdir_archive=MEGAHIT / "{assembly_id}.tar.gz",
    log:
        MEGAHIT / "{assembly_id}.log",
    benchmark:
        MEGAHIT / "benchmark/{assembly_id}.tsv"
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__megahit__run")
    resources:
        runtime=esc("runtime", "assemble__megahit__run"),
        mem_mb=esc("mem_mb", "assemble__megahit__run"),
        cpus_per_task=esc("cpus", "assemble__megahit__run"),
        slurm_partition=esc("partition", "assemble__megahit__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__megahit__run')['nvme']}",
        attempt=esc("attempt", "assemble__megahit__run"),
    params:
        workdir=lambda w: MEGAHIT / w.assembly_id,
        forwards=assembly_reads(1, separator=","),
        reverses=assembly_reads(2, separator=","),
        settings=params["assemble"]["megahit"],
        script_folder=SCRIPT_FOLDER,
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec > "$try_log" 2>&1
        debug "assembly_id={wildcards.assembly_id} threads={threads} settings={params.settings}"

        megahit -1 {params.forwards} -2 {params.reverses} -o {params.workdir} -t {threads} \
            --min-count {params.settings[mincount]} \
            --k-min {params.settings[kmin]} --k-max {params.settings[kmax]} --k-step {params.settings[kstep]} \
            --min-contig-len {params.settings[min_contig_len]} \
            --force --continue --verbose {params.settings[additional_options]}

        python {params.script_folder}/contig_ids.py {wildcards.assembly_id} {params.workdir}/final.contigs.fa \
            | bgzip -l 9 -@ {threads} > {output.contigs}

        tar -cv -I "pigz -9 -p {threads}" --remove-files -f {output.workdir_archive} {params.workdir}

        mv "$try_log" {log}
        """


rule assemble__megahit:
    """Run MEGAHIT for every assembly"""
    input:
        expand(MEGAHIT / "{assembly_id}.fa.gz", assembly_id=ASSEMBLIES),
