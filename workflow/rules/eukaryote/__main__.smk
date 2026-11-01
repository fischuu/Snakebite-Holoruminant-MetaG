include: "__functions__.smk"
include: "4cac.smk"
include: "remag.smk"
include: "tiara.smk"


rule eukaryote:
    """Classify contigs as eukaryotic or prokaryotic (Tiara, 4CAC, REMAG) and bin the eukaryotic ones (REMAG)"""
    input:
        rules.eukaryote__tiara.input,
        rules.eukaryote__4cac.input,
        rules.eukaryote__remag.input,
