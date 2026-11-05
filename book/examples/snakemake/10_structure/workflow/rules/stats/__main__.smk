include: "count.smk"


rule stats:
    """Run the whole stats module"""
    input:
        expand(STATS / "{sample}.txt", sample=SAMPLES),
