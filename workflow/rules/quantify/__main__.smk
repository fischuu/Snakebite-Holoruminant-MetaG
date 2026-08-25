include: "__functions__.smk"
include: "bowtie2.smk"
include: "coverm.smk"
include: "samtools.smk"


rule quantify:
    """Map reads against the assemblies and quantify coverage with CoverM"""
    input:
        rules.quantify__coverm.input,
        rules.quantify__samtools.input,
