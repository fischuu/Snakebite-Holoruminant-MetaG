include: "hosts.smk"


rule reference:
    """Stage and recompress the reference host genomes"""
    input:
        rules.reference__hosts.input,
        PIPELINE_REPORT / "reference.pdf",
