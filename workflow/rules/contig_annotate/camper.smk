rule contig_annotate__camper__annotate:
    """Annotate dereplicate genomes with CAMPER"""
    input:
        fa=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.fa",
    output:
        annotation = CONTIG_CAMPER / "{assembly_id}" / "annotations.tsv",
        distillate = CONTIG_CAMPER / "{assembly_id}" / "distillate.tsv",
    log:
        CONTIG_CAMPER / "{assembly_id}.log",
    container:
        docker["camper"]
    params:
        camper_dir = CONTIG_CAMPER,
        out_dir = lambda wildcards: f"{CONTIG_CAMPER}/{wildcards.assembly_id}",
        camper_db=features["databases"]["camper"],
        nvme=config["nvme_storage"],
        sample=lambda wildcards: f"{wildcards.assembly_id}",
    threads: esc("cpus", "contig_annotate__camper__annotate")
    resources:
        runtime=esc("runtime", "contig_annotate__camper__annotate"),
        mem_mb=esc("mem_mb", "contig_annotate__camper__annotate"),
        cpus_per_task=esc("cpus", "contig_annotate__camper__annotate"),
        slurm_partition=esc("partition", "contig_annotate__camper__annotate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__camper__annotate')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("contig_annotate__camper__annotate"))
    shell:
        """
        # Setup tmp-folder, depending whether there is nvme space or not.

        if [[ -n {params.nvme} ]]; then
            tmp_db_dir={params.nvme}/{params.sample}
        else
            tmp_db_dir={params.out_dir}/camper_db_tmp
        fi

        mkdir -p $tmp_db_dir

        # Copy CAMPER DB locally to tmpdir_camper to avoid collisions
        cp {params.camper_db}/CAMPER.hmm $tmp_db_dir/CAMPER.hmm 2>> {log} 1>&2
        cp {params.camper_db}/CAMPER_hmm_scores.tsv $tmp_db_dir/CAMPER_hmm_scores.tsv 2>> {log} 1>&2
        cp {params.camper_db}/CAMPER_blast.faa $tmp_db_dir/CAMPER_blast.faa 2>> {log} 1>&2
        cp {params.camper_db}/CAMPER_blast_scores.tsv $tmp_db_dir/CAMPER_blast_scores.tsv 2>> {log} 1>&2
        cp {params.camper_db}/CAMPER_distillate.tsv $tmp_db_dir/CAMPER_distillate.tsv 2>> {log} 1>&2

        tmpdir=$tmp_db_dir/tmp
        
        # This is a strange camper requiredment, when it runs in snakemake and folders might be created...
        mkdir -p $tmpdir 2>> {log} 1>&2
        rm -rf $tmpdir 2>> {log} 1>&2
        
        camper_annotate -i {input} \
                        -o $tmpdir \
                        --threads {threads} \
                        --camper_fa_db_loc $tmp_db_dir/CAMPER_blast.faa \
	                      --camper_fa_db_cutoffs_loc $tmp_db_dir/CAMPER_blast_scores.tsv \
	                      --camper_hmm_loc $tmp_db_dir/CAMPER.hmm  \
                        --camper_hmm_cutoffs_loc $tmp_db_dir/CAMPER_hmm_scores.tsv \
        2>> {log} 1>&2

        camper_distill  -a $tmpdir/annotations.tsv \
                        -o {output.distillate} \
	                      --camper_distillate $tmp_db_dir/CAMPER_distillate.tsv \
	      2>> {log} 1>&2
	      
	      # Move all tmp files one level up
        mv "$tmpdir"/* {params.out_dir}/
        """


rule contig_annotate__camper:
    """Run CAMPER on contig gene sequences."""
    input:
         [CONTIG_CAMPER / f"{assembly_id}" / "annotations.tsv" for assembly_id in ASSEMBLIES],
