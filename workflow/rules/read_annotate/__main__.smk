include: "__functions__.smk"
include: "diamond.smk"
include: "kraken2.smk"
include: "krona.smk"
include: "humann.smk"
include: "metaphlan.smk"
include: "ncyc.smk"
include: "phyloflash.smk"
include: "nonpareil.smk"
include: "singlem.smk"
include: "sylph.smk"

rule read_annotate:
    """Run the preprocessing steps, included he evaluation ones"""
    input:
        rules.read_annotate__diamond.input,
        rules.read_annotate__kraken2.input,
        rules.read_annotate__krona.input,
        rules.read_annotate__humann.input,
        rules.read_annotate__metaphlan.input,
        rules.read_annotate__nonpareil.input,
        rules.read_annotate__phyloflash.input,
        rules.read_annotate__singlem.input,
        rules.read_annotate__sylph.input,

rule read_annotate_extra:
    """Run the preprocessing steps, included he evaluation ones"""
    input:
        rules.read_annotate__ncyc.input,
