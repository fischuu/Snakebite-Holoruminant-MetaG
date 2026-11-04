rule quantify__coverm__genome__run:
    """CoverM values of the MAGs in one library, for one method"""
    input:
        alignment=MAG_CRAM,
        index=MAG_CRAI,
        catalogue=MAG_CATALOGUE,
        fai=MAG_CATALOGUE_FAI,
    output:
        COVERM / "genome" / "{method}" / f"{LIBRARY}.tsv",
    container:
        docker["quantify"]
    threads: esc("cpus", "quantify__coverm__genome__run")
    resources:
        runtime=esc("runtime", "quantify__coverm__genome__run"),
        mem_mb=esc("mem_mb", "quantify__coverm__genome__run"),
        cpus_per_task=esc("cpus", "quantify__coverm__genome__run"),
        slurm_partition=esc("partition", "quantify__coverm__genome__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__coverm__genome__run')['nvme']}",
        attempt=esc("attempt", "quantify__coverm__genome__run"),
    log:
        COVERM / "genome" / "{method}" / f"{LIBRARY}.log",
    benchmark:
        COVERM / "genome" / "{method}" / "benchmark" / f"{LIBRARY}.tsv"
    params:
        settings=params["quantify"]["coverm"]["genome"],
    shell:
        """
        exec 2> {log}
        debug "library={wildcards.sample_id}.{wildcards.library_id} method={wildcards.method} separator={params.settings[separator]} min_covered_fraction={params.settings[min_covered_fraction]}"

        # The separator splits a contig id into genome and contig
        samtools view -1 -F 4 -T {input.catalogue} {input.alignment} \
            | coverm genome -b /dev/stdin -m {wildcards.method} -s {params.settings[separator]} \
                --min-covered-fraction {params.settings[min_covered_fraction]} \
            > {output}
        """


rule quantify__coverm__genome_aggregate:
    """Join the genome-level tables of all libraries for one method"""
    input:
        coverm_library_tables("genome"),
    output:
        COVERM / "genome.{method}.tsv",
    log:
        COVERM / "genome.{method}.log",
    benchmark:
        COVERM / "benchmark_genome.{method}.tsv"
    container:
        docker["quantify"]
    params:
        script_folder=SCRIPT_FOLDER,
    threads: esc("cpus", "quantify__coverm__genome_aggregate")
    resources:
        runtime=esc("runtime", "quantify__coverm__genome_aggregate"),
        mem_mb=esc("mem_mb", "quantify__coverm__genome_aggregate"),
        cpus_per_task=esc("cpus", "quantify__coverm__genome_aggregate"),
        slurm_partition=esc("partition", "quantify__coverm__genome_aggregate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__coverm__genome_aggregate')['nvme']}",
        attempt=esc("attempt", "quantify__coverm__genome_aggregate"),
    shell:
        """
        exec > {log} 2>&1
        debug "method={wildcards.method} output={output}"
        Rscript --vanilla {params.script_folder}/coverm_wide_table.R {COVERM}/genome/{wildcards.method} {output}
        """


rule quantify__coverm__genome:
    """Run genome-level CoverM for every configured method"""
    input:
        expand(
            COVERM / "genome.{method}.tsv",
            method=params["quantify"]["coverm"]["genome"]["methods"],
        ),


rule quantify__coverm__contig_one:
    """CoverM values of the catalogue's contigs in one library, for one method"""
    input:
        alignment=MAG_CRAM,
        index=MAG_CRAI,
        catalogue=MAG_CATALOGUE,
        fai=MAG_CATALOGUE_FAI,
    output:
        COVERM / "contig" / "{method}" / f"{LIBRARY}.tsv",
    container:
        docker["quantify"]
    threads: esc("cpus", "quantify__coverm__contig_one")
    resources:
        runtime=esc("runtime", "quantify__coverm__contig_one"),
        mem_mb=esc("mem_mb", "quantify__coverm__contig_one"),
        cpus_per_task=esc("cpus", "quantify__coverm__contig_one"),
        slurm_partition=esc("partition", "quantify__coverm__contig_one"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__coverm__contig_one')['nvme']}",
        attempt=esc("attempt", "quantify__coverm__contig_one"),
    log:
        COVERM / "contig" / "{method}" / f"{LIBRARY}.log",
    benchmark:
        COVERM / "contig" / "{method}" / "benchmark" / f"{LIBRARY}.tsv"
    shell:
        """
        exec 2> {log}
        debug "library={wildcards.sample_id}.{wildcards.library_id} method={wildcards.method}"
        samtools view -1 -F 4 -T {input.catalogue} {input.alignment} \
            | coverm contig -b /dev/stdin -m {wildcards.method} --proper-pairs-only \
            > {output}
        """


rule quantify__coverm__contig_aggregate:
    """Join the contig-level tables of all libraries for one method"""
    input:
        coverm_library_tables("contig"),
    output:
        COVERM / "contig.{method}.tsv",
    log:
        COVERM / "contig.{method}.log",
    benchmark:
        COVERM / "benchmark_contig.{method}.tsv"
    container:
        docker["quantify"]
    params:
        script_folder=SCRIPT_FOLDER,
    threads: esc("cpus", "quantify__coverm__contig_aggregate")
    resources:
        runtime=esc("runtime", "quantify__coverm__contig_aggregate"),
        mem_mb=esc("mem_mb", "quantify__coverm__contig_aggregate"),
        cpus_per_task=esc("cpus", "quantify__coverm__contig_aggregate"),
        slurm_partition=esc("partition", "quantify__coverm__contig_aggregate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__coverm__contig_aggregate')['nvme']}",
        attempt=esc("attempt", "quantify__coverm__contig_aggregate"),
    shell:
        """
        exec > {log} 2>&1
        debug "method={wildcards.method} output={output}"
        Rscript --vanilla {params.script_folder}/coverm_wide_table.R {COVERM}/contig/{wildcards.method} {output}
        """


rule quantify__coverm__contig:
    """Run contig-level CoverM for every configured method"""
    input:
        expand(
            COVERM / "contig.{method}.tsv",
            method=params["quantify"]["coverm"]["contig"]["methods"],
        ),


rule quantify__coverm:
    """Aggregate contig- and genome-level CoverM results"""
    input:
        rules.quantify__coverm__contig.input,
        rules.quantify__coverm__genome.input,
