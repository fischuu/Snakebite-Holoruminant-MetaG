include: "__functions__.smk"
include: "bowtie2.smk"
include: "concoct.smk"
include: "drep.smk"
include: "magscot.smk"
include: "maxbin2.smk"
include: "megahit.smk"
include: "metabat2.smk"
include: "metaspades.smk"


rule assemble:
    """Assemble, bin (CONCOCT/MaxBin2/MetaBAT2), combine bins with MAGScoT and dereplicate with dRep"""
    input:
        rules.assemble__drep.input,
