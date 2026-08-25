include: "__functions__.smk"
include: "bowtie2.smk"
include: "fastp.smk"
include: "fastqc.smk"
include: "samtools.smk"

rule preprocess:
    """Trim reads with fastp, remove host reads with bowtie2, and evaluate with fastqc/samtools"""
    input:
        rules.preprocess__bowtie2.input,
        rules.preprocess__fastp.input,
        rules.preprocess__samtools.input,
        rules.preprocess__fastqc.input,
