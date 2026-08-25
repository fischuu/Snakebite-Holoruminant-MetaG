rule quantify__coverm__genome__run:
    """Compute genome-level coverage for one library against the dereplicated genome set"""
    input:
        cram=QUANT_BOWTIE2 / "{sample_id}.{library_id}.cram",
        crai=QUANT_BOWTIE2 / "{sample_id}.{library_id}.cram.crai",
        reference=DREP / "dereplicated_genomes.fa.gz",
        fai=DREP / "dereplicated_genomes.fa.gz.fai",
    output:
        tsv=COVERM / "genome" / "{method}" / "{sample_id}.{library_id}.tsv",
    container:
        docker["quantify"]
    threads: esc("cpus", "quantify__coverm__genome__run")
    resources:
        runtime=esc("runtime", "quantify__coverm__genome__run"),
        mem_mb=esc("mem_mb", "quantify__coverm__genome__run"),
        cpus_per_task=esc("cpus", "quantify__coverm__genome__run"),
        slurm_partition=esc("partition", "quantify__coverm__genome__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__coverm__genome__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("quantify__coverm__genome__run"))
    log:
        COVERM / "genome" / "{method}" / "{sample_id}.{library_id}.log",
    benchmark:
        COVERM / "genome" / "{method}" / "benchmark" / "{sample_id}.{library_id}.tsv",
    params:
        method="{method}",
        min_covered_fraction=params["quantify"]["coverm"]["genome"][
            "min_covered_fraction"
        ],
        separator=params["quantify"]["coverm"]["genome"]["separator"],
    shell:
        """
        exec 2> {log}
        samtools view --exclude-flags 4 --reference {input.reference} --fast {input.cram} \
            | coverm genome \
                --bam-files /dev/stdin \
                --methods {params.method} \
                --separator {params.separator} \
                --min-covered-fraction {params.min_covered_fraction} \
            > {output.tsv}
        """


rule quantify__coverm__genome_aggregate:
    """Merge per-library genome-coverage TSVs for one CoverM method into one table"""
    input:
        get_tsvs_for_dereplicate_coverm_genome,
    output:
        tsv=COVERM / "genome.{method}.tsv",
    log:
        COVERM / "genome.{method}.log",
    benchmark:
        COVERM / "benchmark_genome.{method}.tsv",
    container:
        docker["quantify"]
    params:
        input_dir=lambda w: COVERM / "genome" / w.method,
        script_folder=SCRIPT_FOLDER,
    threads: esc("cpus", "quantify__coverm__genome_aggregate")
    resources:
        runtime=esc("runtime", "quantify__coverm__genome_aggregate"),
        mem_mb=esc("mem_mb", "quantify__coverm__genome_aggregate"),
        cpus_per_task=esc("cpus", "quantify__coverm__genome_aggregate"),
        slurm_partition=esc("partition", "quantify__coverm__genome_aggregate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__coverm__genome_aggregate')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("quantify__coverm__genome_aggregate"))
    shell:
        """
        exec > {log} 2>&1
        Rscript --vanilla {params.script_folder}/aggregate_coverm.R \
            --input-folder {params.input_dir} \
            --output-file {output}
        """


rule quantify__coverm__genome:
    """Run genome-level CoverM for every configured method"""
    input:
        [
            COVERM / f"genome.{method}.tsv"
            for method in params["quantify"]["coverm"]["genome"]["methods"]
        ],


# coverm contig ----
rule quantify__coverm__contig_one:
    """Compute contig-level coverage for one library against the dereplicated genome set"""
    input:
        cram=QUANT_BOWTIE2 / "{sample_id}.{library_id}.cram",
        crai=QUANT_BOWTIE2 / "{sample_id}.{library_id}.cram.crai",
        reference=DREP / "dereplicated_genomes.fa.gz",
        fai=DREP / "dereplicated_genomes.fa.gz.fai",
    output:
        tsv=COVERM / "contig" / "{method}" / "{sample_id}.{library_id}.tsv",
    container:
        docker["quantify"]
    threads: esc("cpus", "quantify__coverm__contig_one")
    resources:
        runtime=esc("runtime", "quantify__coverm__contig_one"),
        mem_mb=esc("mem_mb", "quantify__coverm__contig_one"),
        cpus_per_task=esc("cpus", "quantify__coverm__contig_one"),
        slurm_partition=esc("partition", "quantify__coverm__contig_one"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__coverm__contig_one')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("quantify__coverm__contig_one"))
    log:
        COVERM / "contig" / "{method}" / "{sample_id}.{library_id}.log",
    benchmark:
        COVERM / "contig" / "{method}" / "benchmark" / "{sample_id}.{library_id}.tsv",
    params:
        method="{method}",
    shell:
        """
        exec 2> {log}
        samtools view --exclude-flags 4 --reference {input.reference} --fast {input.cram} \
            | coverm contig --bam-files /dev/stdin --methods {params.method} --proper-pairs-only \
            > {output.tsv}
        """


rule quantify__coverm__contig_aggregate:
    """Merge per-library contig-coverage TSVs for one CoverM method into one table"""
    input:
        get_tsvs_for_dereplicate_coverm_contig,
    output:
        tsv=COVERM / "contig.{method}.tsv",
    log:
        COVERM / "contig.{method}.log",
    benchmark:
        COVERM / "benchmark_contig.{method}.tsv",
    container:
        docker["quantify"]
    params:
        input_dir=lambda w: COVERM / "contig" / w.method,
        script_folder=SCRIPT_FOLDER,
    threads: esc("cpus", "quantify__coverm__contig_aggregate")
    resources:
        runtime=esc("runtime", "quantify__coverm__contig_aggregate"),
        mem_mb=esc("mem_mb", "quantify__coverm__contig_aggregate"),
        cpus_per_task=esc("cpus", "quantify__coverm__contig_aggregate"),
        slurm_partition=esc("partition", "quantify__coverm__contig_aggregate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__coverm__contig_aggregate')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("quantify__coverm__contig_aggregate"))
    shell:
        """
        exec > {log} 2>&1
        Rscript --vanilla {params.script_folder}/aggregate_coverm.R \
            --input-folder {params.input_dir} \
            --output-file {output}
        """


rule quantify__coverm__contig:
    """Run contig-level CoverM for every configured method"""
    input:
        [
            COVERM / f"contig.{method}.tsv"
            for method in params["quantify"]["coverm"]["contig"]["methods"]
        ],


rule quantify__coverm:
    """Aggregate contig- and genome-level CoverM results"""
    input:
        rules.quantify__coverm__contig.input,
        rules.quantify__coverm__genome.input,
