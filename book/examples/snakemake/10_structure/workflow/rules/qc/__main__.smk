include: "filter.smk"


rule qc:
    """Run the whole qc module"""
    input:
        expand(QC / "{sample}.fastq.gz", sample=SAMPLES),
