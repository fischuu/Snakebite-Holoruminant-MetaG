rule contig_annotate__hmmer__assign:
    """Run HMMER."""
    input:
        fa=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.fa",
        database=lambda w: features["databases"]["hmmer"][w.hmmer_db],
    output:
        out = CONTIG_HMMER / "{hmmer_db}" / "{assembly_id}.out",
        aln = CONTIG_HMMER / "{hmmer_db}" / "{assembly_id}.aln",
        tblout = CONTIG_HMMER / "{hmmer_db}" / "{assembly_id}.tblout.tsv",
        domtblout = CONTIG_HMMER / "{hmmer_db}" / "{assembly_id}.domains-tblout.tsv",
        pfam = CONTIG_HMMER / "{hmmer_db}" / "{assembly_id}.pfam",
    log:
        CONTIG_HMMER / "{hmmer_db}_{assembly_id}.log",
    benchmark:
        CONTIG_HMMER / "benchmark/{hmmer_db}_{assembly_id}.tsv",
    threads: esc("cpus", "contig_annotate__hmmer__assign"),
    resources:
        runtime=esc("runtime", "contig_annotate__hmmer__assign"),
        mem_mb=esc("mem_mb", "contig_annotate__hmmer__assign"),
        cpus_per_task=esc("cpus", "contig_annotate__hmmer__assign"),
        slurm_partition=esc("partition", "contig_annotate__hmmer__assign"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__hmmer__assign')['nvme']}",
        attempt=lambda wildcards, attempt: attempt,
    retries: len(get_escalation_order("contig_annotate__hmmer__assign")) - 1,
    params:
        out_folder=lambda w: CONTIG_HMMER / w.hmmer_db,
        domt=lambda w: params["contig_annotate"]["hmmer"]["domt"].get(w.hmmer_db, params["contig_annotate"]["hmmer"]["domt"]["fallback"])
    container:
        docker["assemble"],
    shell:
        """
           echo "=== Running hmmsearch for assembly {wildcards.assembly_id} on database {wildcards.hmmer_db} ===" > {log}
           echo "Start time: $(date)" >> {log}
        
           hmmsearch \
            -o {output.out} \
            -A {output.aln} \
            --tblout {output.tblout} \
            --domtblout {output.domtblout} \
            --pfamtblout {output.pfam} \
            --acc \
            --domT {params.domt} \
            {input.database} \
            {input.fa} 2>> {log} 1>&2
            
            echo "End time: $(date)" >> {log}
            echo "=== hmmsearch finished for assembly {wildcards.assembly_id} ===" >> {log}
        """

rule contig_annotate__hmmer:
    """Run all HMMER steps"""
    input:
        [
            CONTIG_HMMER / hmmer_db / f"{assembly_id}.out"
            for assembly_id in ASSEMBLIES
            for hmmer_db in features["databases"]["hmmer"]
        ] 
