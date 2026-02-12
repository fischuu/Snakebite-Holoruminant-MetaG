
if params["assemble"]["samtools"]["out_type"].upper() == "CRAM":
    rule contig_annotate__cramToBam:
        """Create temporary bam-files for quantification"""
        input:
            ASSEMBLE_BOWTIE2 / "{assembly_id}.{sample_id}.{library_id}.cram"
        output:
            temp(ASSEMBLE_BOWTIE2 / "{assembly_id}.{sample_id}.{library_id}.bam"),
        log:
            log=ASSEMBLE_BOWTIE2 / "{assembly_id}.{sample_id}.{library_id}.cramToBam.log",
        container:
            docker["assemble"]
        threads: esc("cpus", "contig_annotate__cramToBam")
        resources:
            runtime=esc("runtime", "contig_annotate__cramToBam"),
            mem_mb=esc("mem_mb", "contig_annotate__cramToBam"),
            cpus_per_task=esc("cpus", "contig_annotate__cramToBam"),
            slurm_partition=esc("partition", "contig_annotate__cramToBam"),
            gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__cramToBam')['nvme']}",
            attempt=get_attempt,
        retries: len(get_escalation_order("contig_annotate__cramToBam"))
        shell:
            """
            echo "=== Running cramToBam for assembly {wildcards.assembly_id}, sample {wildcards.sample_id} and library {wildcards.library_id} ===" > {log}
            echo "Start time: $(date)" >> {log}
            
            #samtools index {input} 2> {log} 1>&2
            samtools view -b -o {output} {input} 2> {log} 1>&2
            
            echo "End time: $(date)" >> {log}
            echo "=== Finished running cramToBam for assembly {wildcards.assembly_id}, sample {wildcards.sample_id} and library {wildcards.library_id} ===" >> {log}
            """


rule contig_annotate__featurecounts_run:
    """
    Quantify the mapped assembly reads in predicted genes (featureCounts).
    """
    input:
        bam=ASSEMBLE_BOWTIE2 / "{assembly_id}.{sample_id}.{library_id}.bam",
        gtf=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.gtf",
    output:
        file=CONTIG_FEATURECOUNTS / "{assembly_id}/{assembly_id}_{sample_id}.{library_id}.prodigal_fc.txt",
    log:
        CONTIG_FEATURECOUNTS / "{assembly_id}/{assembly_id}_{sample_id}.{library_id}.prodigal_fc.log",
    threads: esc("cpus", "contig_annotate__featurecounts_run")
    resources:
        runtime=esc("runtime", "contig_annotate__featurecounts_run"),
        mem_mb=esc("mem_mb", "contig_annotate__featurecounts_run"),
        cpus_per_task=esc("cpus", "contig_annotate__featurecounts_run"),
        slurm_partition=esc("partition", "contig_annotate__featurecounts_run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__featurecounts_run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("contig_annotate__featurecounts_run"))
    container: docker["subread"]
    shell:"""
        featureCounts -p \
                      -T {threads} \
                      -a {input.gtf} \
                      -o {output.file} \
                      -t CDS \
                      -g ID \
                      {input.bam} 2> {log}
    """
    
    
rule contig_annotate__featurecounts:
    """Quantify all samples for all the assemblies that they belong to"""
    input:
        [
            CONTIG_FEATURECOUNTS / "{assembly_id}/{assembly_id}_{sample_id}.{library_id}.prodigal_fc.txt"
            for assembly_id, sample_id, library_id in ASSEMBLY_SAMPLE_LIBRARY
        ],
