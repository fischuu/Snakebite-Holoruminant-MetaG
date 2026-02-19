include: "__functions__.smk"
include: "camper.smk"
include: "diamond.smk"
include: "eggnog.smk"
include: "eggnog7.smk"
include: "ncyc.smk"
include: "featurecounts.smk"
include: "hmmer.smk"
include: "prodigal.smk"

rule contig_annotate:
    """Annotate on contig level"""
    input:
        rules.contig_annotate__camper.input,
        [
            CONTIG_EGGNOG / f"{assembly_id}/eggnog_output.emapper.annotations"
            for assembly_id in ASSEMBLIES
        ],
        lambda wildcards: [
            CONTIG_FEATURECOUNTS / f"{assembly_id}/{assembly_id}_{sample_id}.{library_id}.prodigal_fc.txt"
            for assembly_id, sample_id, library_id in ASSEMBLY_SAMPLE_LIBRARY
        ],
        rules.contig_annotate__diamond.input,
        rules.contig_annotate__hmmer.input,
        rules.contig_annotate__eggnog7.input,        

rule contig_annotate_extra:
    input:
        rules.contig_annotate__ncyc.input,
