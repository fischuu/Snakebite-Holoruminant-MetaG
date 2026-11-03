include: "__functions__.smk"
include: "assemble.smk"
include: "contig_annotate.smk"
include: "mag_annotate.smk"
include: "preprocess.smk"
include: "quantify.smk"
include: "read_annotate.smk"
include: "reads.smk"
include: "reference.smk"

rule report:
    """Generate the report for every module"""
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
    """Report assemble module"""
    input:
        rules.report__assemble.output,

rule report_contig_annotate:
    """Report contig_annotate module"""
    input:
        rules.report__contig_annotate.output,
        
rule report_mag_annotate:
    """Report mag_annotate module"""
    input:
        rules.report__mag_annotate.output,
        
rule report_preprocess:
    """Report preprocess module"""
    input:
        rules.report__preprocess.output,

rule report_quantify:
    """Report preprocess module"""
    input:
        rules.report__quantify.output,

rule report_read_annotate:
    """Report read_annotate module"""
    input:
        rules.report__read_annotate.output,

rule report_reads:
    """Report reads module"""
    input:
        rules.report__reads.output,

rule report_reference:
    """Report reference module"""
    input:
        rules.report__reference.output,
