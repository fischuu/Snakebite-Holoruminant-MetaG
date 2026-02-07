rule mag_annotate__camper__annotate:
    """Annotate dereplicate genomes with CAMPER"""
    input:
        genes=DRAM / "annotate" / "genes.faa",
        annotation=DRAM / "annotate" / "annotations.tsv",
    output:
        annotation=CAMPER / "annotations.tsv",
        distill=CAMPER / "distill.tsv"        
    log:
        CAMPER / "camper.log",
    conda:
        "__environment__.yml"
    container:
        docker["camper"]
    params:
        camper_dir = CAMPER,
        camper_db=features["databases"]["camper"],
        nvme=config["nvme_storage"],
    threads: esc("cpus", "mag_annotate__camper__annotate")
    resources:
        runtime=esc("runtime", "mag_annotate__camper__annotate"),
        mem_mb=esc("mem_mb", "mag_annotate__camper__annotate"),
        cpus_per_task=esc("cpus", "mag_annotate__camper__annotate"),
        slurm_partition=esc("partition", "mag_annotate__camper__annotate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__camper__annotate')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("mag_annotate__camper__annotate"))
    shell:
        """
        # Setup tmp-folder, depending whether there is nvme space or not.

        if [[ -n {params.nvme} ]]; then
            tmp_db_dir={params.nvme}
        else
            tmp_db_dir={params.camper_dir}/camper_db_tmp
        fi

        mkdir -p $tmp_db_dir
        cp {params.camper_db}/* $tmp_db_dir 2>> {log} 1>&2
        
        tmpdir={params.camper_dir}/tmp
        
        # This is a strange camper requiredment, when it runs in snakemake and folders might be created...
        mkdir -p $tmpdir
        rm -rf $tmpdir

        camper_annotate -i {input.genes} \
                        -o $tmpdir \
                        --threads {threads} \
                        --camper_fa_db_loc $tmp_db_dir/CAMPER_blast.faa \
	                      --camper_fa_db_cutoffs_loc $tmp_db_dir/CAMPER_blast_scores.tsv \
	                      --camper_hmm_loc $tmp_db_dir/CAMPER.hmm  \
                        --camper_hmm_cutoffs_loc $tmp_db_dir/CAMPER_hmm_scores.tsv \
                        2>> {log} 1>&2
        
        camper_distill  -a $tmpdir/annotations.tsv \
                        -o {output.distill} \
	                      --camper_distillate $tmp_db_dir/CAMPER_distillate.tsv \
	      2>> {log} 1>&2
	      
	      # Move all tmp files one level up
        mv "$tmpdir"/* {params.camper_dir}/
        """

rule mag_annotate__camper:
    """Run CAMPER on dereplicated genomes."""
    input:
        rules.mag_annotate__camper__annotate.output,
