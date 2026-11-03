include: "bakta.smk"
include: "camper.smk"
include: "quast.smk"
include: "gtdbtk.smk"
include: "dram.smk"
include: "dram_mag.smk"
include: "eggnog.smk"
include: "checkm2.smk"
include: "proteinortho.smk"
include: "phylophlan.smk"


rule mag_annotate:
    """Annotate the dereplicated MAG catalogue with every configured tool"""
    input:
        rules.mag_annotate__bakta.output,
        rules.mag_annotate__bakta_mags.input,
        rules.mag_annotate__camper.input,
        rules.mag_annotate__eggnog.output,
        rules.mag_annotate__quast.output,
        rules.mag_annotate__checkm2__predict.output,
        rules.mag_annotate__gtdbtk__classify.output,
        rules.mag_annotate__dram.input,
        rules.mag_annotate__dram_mags.input,
        rules.mag_annotate__proteinortho.output,
        rules.mag_annotate__phylophlan.output,
