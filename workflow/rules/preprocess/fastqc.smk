rule preprocess__fastqc__fastp:
    """FastQC reports for the fastp-trimmed reads"""
    input:
        [
            FASTP / f"{sample_id}.{library_id}_{end}_fastqc.{ext}"
            for sample_id, library_id in SAMPLE_LIBRARY
            for end in (1, 2)
            for ext in ("html", "zip")
        ],


rule preprocess__fastqc__nonhost:
    """FastQC reports for the reads left over after each host-decontamination step"""
    input:
        [
            PRE_BOWTIE2 / f"non{genome}" / f"{sample_id}.{library_id}_{end}_fastqc.{ext}"
            for genome in HOST_NAMES
            for sample_id, library_id in SAMPLE_LIBRARY
            for end in (1, 2)
            for ext in ("html", "zip")
        ],


rule preprocess__fastqc:
    """Aggregate every FastQC report produced during preprocessing"""
    input:
        rules.preprocess__fastqc__fastp.input,
        rules.preprocess__fastqc__nonhost.input,
