_BIN_FILES = DREP / "separated_bins"


rule assemble__drep__split_bins:
    """Write every refined bin of all assemblies to its own FASTA, the way dRep takes its genomes"""
    input:
        expand(MAGSCOT / "{assembly_id}.fa.gz", assembly_id=ASSEMBLIES),
    output:
        directory(_BIN_FILES),
    log:
        DREP / "separate_bins.log",
    benchmark:
        DREP / "benchmark/separate_bins.tsv"
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__drep__split_bins")
    resources:
        runtime=esc("runtime", "assemble__drep__split_bins"),
        mem_mb=esc("mem_mb", "assemble__drep__split_bins"),
        cpus_per_task=esc("cpus", "assemble__drep__split_bins"),
        slurm_partition=esc("partition", "assemble__drep__split_bins"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__drep__split_bins')['nvme']}",
        attempt=esc("attempt", "assemble__drep__split_bins"),
    params:
        script_folder=SCRIPT_FOLDER,
    shell:
        """
        exec > {log} 2>&1
        debug "bin_files={output} assemblies=$(echo {input} | wc -w)"
        {params.script_folder}/split_bins.sh {output} {input}
        """


rule assemble__drep__run:
    """Dereplicate the bins of all assemblies into one set of genomes with dRep"""
    input:
        _BIN_FILES,
    output:
        genomes=directory(MAG_GENOMES),
        archives=expand(DREP / "{section}.tar.gz", section=("data", "data_tables")),
    log:
        DREP / "drep.log",
    benchmark:
        DREP / "benchmark/drep_run.tsv"
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__drep__run")
    resources:
        runtime=esc("runtime", "assemble__drep__run"),
        mem_mb=esc("mem_mb", "assemble__drep__run"),
        cpus_per_task=esc("cpus", "assemble__drep__run"),
        slurm_partition=esc("partition", "assemble__drep__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__drep__run')['nvme']}",
        attempt=esc("attempt", "assemble__drep__run"),
    params:
        settings=params["assemble"]["drep"],
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec > "$try_log" 2>&1
        debug "threads={threads} settings={params.settings}"

        # dRep will not start over in a folder holding the results of a failed attempt
        rm -rf {DREP}/{{data,data_tables,dereplicated_genomes,figures,log}}

        dRep dereplicate {DREP} -g {input}/*.fa -p {threads} \
            -comp {params.settings[completeness]} -con {params.settings[contamination]} \
            -pa {params.settings[P_ani]} -sa {params.settings[S_ani]} -nc {params.settings[nc]} \
            {params.settings[extra]}

        # dRep can report that CheckM failed, still exit with 0, and leave no genomes
        if [ -z "$(find {output.genomes} -type f -name '*.fa*' -print -quit 2>/dev/null)" ]; then
            echo "dRep wrote no genomes. Its messages are above, and {DREP}/log/logger.log has the details."
            exit 1
        fi

        for section in data data_tables; do
            tar -C {DREP} -cv -I "pigz -p {threads}" --remove-files -f {DREP}/$section.tar.gz $section
        done

        find {output.genomes} -type f -not -name "*.gz" -exec pigz -p {threads} {{}} +

        mv "$try_log" {log}
        """


rule assemble__drep__catalogue:
    """Concatenate the dereplicated genomes into the MAG catalogue"""
    input:
        MAG_GENOMES,
    output:
        MAG_CATALOGUE,
    log:
        DREP / "dereplicated_genomes.log",
    benchmark:
        DREP / "benchmark/join_genomes.tsv"
    container:
        docker["assemble"]
    threads: esc("cpus", "assemble__drep__catalogue")
    resources:
        runtime=esc("runtime", "assemble__drep__catalogue"),
        mem_mb=esc("mem_mb", "assemble__drep__catalogue"),
        cpus_per_task=esc("cpus", "assemble__drep__catalogue"),
        slurm_partition=esc("partition", "assemble__drep__catalogue"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'assemble__drep__catalogue')['nvme']}",
        attempt=esc("attempt", "assemble__drep__catalogue"),
    shell:
        """
        exec 2> {log}
        debug "genomes={input} threads={threads} catalogue={output}"
        zcat {input}/*.fa.gz | bgzip -l 9 -@ {threads} > {output}
        """


rule assemble__drep:
    """Build the MAG catalogue from the bins of all assemblies"""
    input:
        MAG_CATALOGUE,
