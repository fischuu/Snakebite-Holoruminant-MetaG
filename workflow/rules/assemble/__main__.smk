include: "__functions__.smk"
include: "megahit.smk"
include: "metaspades.smk"
include: "bowtie2.smk"
include: "binners/concoct.smk"
include: "binners/maxbin2.smk"
include: "binners/metabat2.smk"
include: "magscot.smk"
include: "drep.smk"


rule assemble:
    """Assemble, bin (CONCOCT/MaxBin2/MetaBAT2), combine bins with MAGScoT and dereplicate with dRep"""
    input:
        MAG_CATALOGUE,
        PIPELINE_REPORT / "assemble.pdf",
