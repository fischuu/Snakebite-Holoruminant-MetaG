rule stats__count:
    input:
        QC / "{sample}.fastq.gz",
    output:
        STATS / "{sample}.txt",
    shell:
        "zcat {input} | wc -l | awk '{{print $1 / 4}}' > {output}"
