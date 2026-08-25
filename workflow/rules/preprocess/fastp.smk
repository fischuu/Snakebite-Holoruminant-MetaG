# ---------- preprocess__fastp__run ----------
rule preprocess__fastp__run:
    """Run fastp on one library"""
    input:
        forward_=READS / "{sample_id}.{library_id}_1.fq.gz",
        reverse_=READS / "{sample_id}.{library_id}_2.fq.gz",
    output:
        forward_=FASTP / "{sample_id}.{library_id}_1.fq.gz",
        reverse_=FASTP / "{sample_id}.{library_id}_2.fq.gz",
        unpaired1=FASTP / "{sample_id}.{library_id}_u1.fq.gz",
        unpaired2=FASTP / "{sample_id}.{library_id}_u2.fq.gz",
        html=FASTP / "{sample_id}.{library_id}_fastp.html",
        json=FASTP / "{sample_id}.{library_id}_fastp.json",
    log:
        FASTP / "{sample_id}.{library_id}.log",
    benchmark:
        FASTP / "benchmark/{sample_id}.{library_id}.tsv",
    container:
        docker["preprocess"],
    params:
        adapter_forward=get_forward_adapter,
        adapter_reverse=get_reverse_adapter,
        extra=params["preprocess"]["fastp"]["extra"],
        length_required=params["preprocess"]["fastp"]["length_required"],
        work_prefix=lambda w: FASTP / f"{w.sample_id}.{w.library_id}_tmp",
    threads: esc("cpus", "preprocess__fastp__run"),
    resources:
        runtime=esc("runtime", "preprocess__fastp__run"),
        mem_mb=esc("mem_mb", "preprocess__fastp__run"),
        cpus_per_task=esc("cpus", "preprocess__fastp__run"),
        slurm_partition=esc("partition", "preprocess__fastp__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'preprocess__fastp__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("preprocess__fastp__run")),
    shell: """
        exec > {log}.{resources.attempt} 2>&1

        fastp \
            --in1 {input.forward_} \
            --in2 {input.reverse_} \
            --out1 {params.work_prefix}_1.fq \
            --out2 {params.work_prefix}_2.fq \
            --unpaired1 {params.work_prefix}_u1.fq \
            --unpaired2 {params.work_prefix}_u2.fq \
            --html {output.html} \
            --json {output.json} \
            --verbose \
            --adapter_sequence {params.adapter_forward} \
            --adapter_sequence_r2 {params.adapter_reverse} \
            --length_required {params.length_required} \
            --thread {threads} \
            {params.extra}

        declare -A dest=(
            [1]={output.forward_}
            [2]={output.reverse_}
            [u1]={output.unpaired1}
            [u2]={output.unpaired2}
        )
        echo "Compressing and validating outputs"
        for suffix in "${{!dest[@]}}"; do
            bgzip --compress-level 9 --threads {threads} {params.work_prefix}_${{suffix}}.fq
            mv {params.work_prefix}_${{suffix}}.fq.gz "${{dest[$suffix]}}"
            gzip --test "${{dest[$suffix]}}"
        done
        echo "All outputs validated"

        mv {log}.{resources.attempt} {log}
    """

# ---------- preprocess__fastp ----------
rule preprocess__fastp:
    """Aggregate all fastp outputs"""
    input:
        reads=[
            FASTP / f"{sample_id}.{library_id}_{end}.fq.gz"
            for sample_id, library_id in SAMPLE_LIBRARY
            for end in "1 2 u1 u2".split()
        ],
        json=[
            FASTP / f"{sample_id}.{library_id}_fastp.json"
            for sample_id, library_id in SAMPLE_LIBRARY
        ]
