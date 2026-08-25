
if params["assemble"]["samtools"]["out_type"].upper() == "CRAM":
    rule contig_annotate__cram_to_bam:
        """Create temporary bam-files for quantification"""
        input:
            ASSEMBLE_BOWTIE2 / "{assembly_id}.{sample_id}.{library_id}.cram"
        output:
            temp(ASSEMBLE_BOWTIE2 / "{assembly_id}.{sample_id}.{library_id}.bam"),
        log:
            log=ASSEMBLE_BOWTIE2 / "{assembly_id}.{sample_id}.{library_id}.cramToBam.log",
        container:
            docker["assemble"]
        threads: esc("cpus", "contig_annotate__cram_to_bam")
        resources:
            runtime=esc("runtime", "contig_annotate__cram_to_bam"),
            mem_mb=esc("mem_mb", "contig_annotate__cram_to_bam"),
            cpus_per_task=esc("cpus", "contig_annotate__cram_to_bam"),
            slurm_partition=esc("partition", "contig_annotate__cram_to_bam"),
            gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__cram_to_bam')['nvme']}",
            attempt=get_attempt,
        retries: len(get_escalation_order("contig_annotate__cram_to_bam"))
        shell:
            """
            exec > {log} 2>&1
            echo "[{wildcards.assembly_id}] converting {wildcards.sample_id}.{wildcards.library_id} CRAM to BAM"
            samtools view -b -o {output} {input}
            echo "done"
            """


rule contig_annotate__featurecounts__run:
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
    threads: esc("cpus", "contig_annotate__featurecounts__run")
    resources:
        runtime=esc("runtime", "contig_annotate__featurecounts__run"),
        mem_mb=esc("mem_mb", "contig_annotate__featurecounts__run"),
        cpus_per_task=esc("cpus", "contig_annotate__featurecounts__run"),
        slurm_partition=esc("partition", "contig_annotate__featurecounts__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__featurecounts__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("contig_annotate__featurecounts__run"))
    container: docker["subread"]
    shell:"""
        featureCounts -p \
                      -T {threads} \
                      -F GFF3 \
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
