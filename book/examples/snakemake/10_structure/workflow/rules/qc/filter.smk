rule qc__filter:
    input:
        "data/{sample}_R1.fastq.gz",
    output:
        QC / "{sample}.fastq.gz",
    shell:
        """
        zcat {input} | paste - - - - | awk -F '\\t' 'length($2) >= 50' | tr '\\t' '\\n' | gzip > {output}
        """
