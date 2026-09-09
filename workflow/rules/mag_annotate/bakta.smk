rule mag_annotate__bakta:
    """Run Bakta over the dereplicated mags"""
    input:
        contigs=DREP / "dereplicated_genomes.fa.gz",
    output:
        tsv=BAKTA / "bakta.tsv",
        faa=BAKTA / "bakta.faa",
    log:
        BAKTA / "bakta.log",
    benchmark:
        BAKTA / "benchmark.tsv",
    container:
        docker["mag_annotate"]
    params:
        out_dir=BAKTA,
        db=features["databases"]["bakta"],
        options=params["mag_annotate"]["bakta"]["additional_options"],
    threads: esc("cpus", "mag_annotate__bakta")
    resources:
        runtime=esc("runtime", "mag_annotate__bakta"),
        mem_mb=esc("mem_mb", "mag_annotate__bakta"),
        cpus_per_task=esc("cpus", "mag_annotate__bakta"),
        slurm_partition=esc("partition", "mag_annotate__bakta"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__bakta')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("mag_annotate__bakta"))
    shell:
        """
        # bakta's own tempfile handling is fine with the container's default
        # /tmp, but it spawns tRNAscan-SE as a subprocess, which does its own
        # independent $TMPDIR lookup for Infernal/cmsearch scratch files and
        # inherits whatever TMPDIR this shell has -- on this cluster that's a
        # SLURM-assigned per-job path that only exists on the real host /tmp,
        # not inside the container's bind-mounted one (same root cause as the
        # magscot/parallel fix). Point it at our own guaranteed-to-exist
        # subdirectory instead of trusting the inherited value.
        tmp_dir="/tmp/bakta.$$"
        mkdir -p "$tmp_dir"
        export TMPDIR="$tmp_dir"

        bakta --db {params.db} \
              --force \
              --verbose \
              --output {params.out_dir} \
              --prefix bakta \
              --threads {threads} \
              {params.options} \
              {input.contigs} \
              > {log} 2>&1

        rm --recursive --force "$tmp_dir"

        # bakta's own invocation truncates {log}, so this diagnostic line has to
        # come after it rather than before, or it would be wiped out.
        debug "db={params.db} out_dir={params.out_dir} threads={threads} contigs={input.contigs} tmp_dir=$tmp_dir" 2>> {log}
        """

rule mag_annotate__bakta_mags__run:
    """Run Bakta over the dereplicated mags"""
    input:
        contigs=MAGSCOT / "{assembly_id}.fa.gz",
    output:
        tsv=BAKTAMAG / "bakta_{assembly_id}.tsv",
        faa=BAKTAMAG / "bakta_{assembly_id}.faa",
    log:
        BAKTAMAG / "bakta_{assembly_id}.log",
    benchmark:
        BAKTAMAG / "benchmark_{assembly_id}.tsv",
    container:
        docker["mag_annotate"]
    params:
        out_dir=BAKTAMAG,
        db=features["databases"]["bakta"],
        options=params["mag_annotate"]["bakta"]["additional_options"],
    threads: esc("cpus", "mag_annotate__bakta_mags__run")
    resources:
        runtime=esc("runtime", "mag_annotate__bakta_mags__run"),
        mem_mb=esc("mem_mb", "mag_annotate__bakta_mags__run"),
        cpus_per_task=esc("cpus", "mag_annotate__bakta_mags__run"),
        slurm_partition=esc("partition", "mag_annotate__bakta_mags__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__bakta_mags__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("mag_annotate__bakta_mags__run"))
    shell:
        """
        # See mag_annotate__bakta above: tRNAscan-SE (spawned by bakta as a
        # subprocess) does its own $TMPDIR lookup, which on this cluster
        # inherits a SLURM per-job path invisible inside the container's
        # bind-mounted /tmp. Use our own guaranteed-to-exist subdirectory.
        tmp_dir="/tmp/bakta_mags.{wildcards.assembly_id}.$$"
        mkdir -p "$tmp_dir"
        export TMPDIR="$tmp_dir"

        bakta --db {params.db} \
              --force \
              --verbose \
              --output {params.out_dir} \
              --prefix bakta_{wildcards.assembly_id} \
              --threads {threads} \
              {params.options} \
              {input.contigs} \
              > {log} 2>&1

        rm --recursive --force "$tmp_dir"

        debug "assembly_id={wildcards.assembly_id} db={params.db} out_dir={params.out_dir} threads={threads} tmp_dir=$tmp_dir" 2>> {log}
        """

rule mag_annotate__bakta_mags:
    """Run Bakta over the dereplicated mags"""
    input:
        expand(BAKTAMAG / "bakta_{assembly_id}.faa", assembly_id=ASSEMBLIES),

