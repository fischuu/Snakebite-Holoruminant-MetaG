include: "__functions__.smk"
include: "assemble.smk"
include: "contig_annotate.smk"
include: "eukaryote.smk"
include: "mag_annotate.smk"
include: "preprocess.smk"
include: "quantify.smk"
include: "read_annotate.smk"
include: "reads.smk"
include: "reference.smk"


rule report:
    """Generate the report of every module of the rule all. The module eukaryote is optional, and has its own target report_eukaryote"""
    input:
        rules.report__assemble.output,
        rules.report__contig_annotate.output,
        rules.report__mag_annotate.output,
        rules.report__preprocess.output,
        rules.report__quantify.output,
        rules.report__read_annotate.output,
        rules.report__reads.output,
        rules.report__reference.output,


rule report_assemble:
    """Report on the module assemble"""
    input:
        rules.report__assemble.output,


rule report_contig_annotate:
    """Report on the module contig_annotate"""
    input:
        rules.report__contig_annotate.output,


rule report_eukaryote:
    """Report on the module eukaryote"""
    input:
        rules.report__eukaryote.output,


rule report_mag_annotate:
    """Report on the module mag_annotate"""
    input:
        rules.report__mag_annotate.output,


rule report_preprocess:
    """Report on the module preprocess"""
    input:
        rules.report__preprocess.output,


rule report_quantify:
    """Report on the module quantify"""
    input:
        rules.report__quantify.output,


rule report_read_annotate:
    """Report on the module read_annotate"""
    input:
        rules.report__read_annotate.output,


rule report_reads:
    """Report on the module reads"""
    input:
        rules.report__reads.output,


rule report_reference:
    """Report on the module reference"""
    input:
        rules.report__reference.output,
