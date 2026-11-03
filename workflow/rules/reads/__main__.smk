include: "__functions__.smk"
include: "link.smk"
include: "fastqc.smk"


rule reads:
    """Symlink the raw reads and run FastQC on them"""
    input:
        rules.reads__link.input,
        rules.reads__fastqc.input,
