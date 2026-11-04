include: "filter.smk"
include: "fragile.smk"


rule qc:
    """Run the whole module"""
    input:
        expand("results/qc/{sample}.fastq.gz", sample=SAMPLES),
        "results/qc/fragile.txt",
