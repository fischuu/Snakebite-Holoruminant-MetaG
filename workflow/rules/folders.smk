# Generate more configuration keys
# Define the script_folder dynamically based on the pipeline_folder
SCRIPT_FOLDER = os.path.join(config["pipeline_folder"], "workflow", "scripts")

READS = Path("results/reads/")
WD = os.getcwd()

# reference
REFERENCE = Path("results/reference/")
HOSTS = REFERENCE / "hosts"

# preprocess
PRE = Path("results/preprocess/")
FASTP = PRE / "fastp/"
PRE_INDEX = PRE / "index/"
PRE_BOWTIE2 = PRE / "bowtie2"
NONHOST = PRE / "nonhost/"
PRE_QUANT = PRE / "quantification/"

# read_annotate
READ_ANNOT = Path("results/read_annotate/")
NONPAREIL = READ_ANNOT / "nonpareil/"
METAPHLAN = READ_ANNOT / "metaphlan/"
HUMANN = READ_ANNOT / "humann/"
PHYLOFLASH = READ_ANNOT / "phyloflash/"
SINGLEM = READ_ANNOT / "singlem/"
PRE_COVERM = READ_ANNOT / "coverm/"
KRAKEN2 = READ_ANNOT / "kraken2/"
KRONA = READ_ANNOT / "krona/"
DIAMOND = READ_ANNOT / "diamond/"
PRE_SYLPH = READ_ANNOT / "sylph/"
NCYC = READ_ANNOT / "ncyc"

# assemble
ASSEMBLE = Path("results/assemble/")
MEGAHIT = ASSEMBLE / "megahit/"
METASPADES = ASSEMBLE / "metaspades/"
ASSEMBLE_RENAME = ASSEMBLE / "renaming/"
ASSEMBLE_INDEX = ASSEMBLE / "index/"
ASSEMBLE_BOWTIE2 = ASSEMBLE / "bowtie2/"
CONCOCT = ASSEMBLE / "concoct/"
METABAT2 = ASSEMBLE / "metabat2/"
MAXBIN2 = ASSEMBLE / "maxbin2/"
# VAMB = ASSEMBLE / "vamb/"  # This could be a metabinner
MAGSCOT = ASSEMBLE / "magscot/"
PRODIGAL = MAGSCOT / "prodigal/"
DREP = ASSEMBLE / "drep/"

PROVIDED = ASSEMBLE / config["assembler"]

#PROVIDED = ASSEMBLE / "long_reads"

# quantify
QUANT = Path("results/quantify/")
QUANT_INDEX = QUANT / "index/"
QUANT_BOWTIE2 = QUANT / "bowtie2/"
COVERM = QUANT / "coverm/"

# dereplicate evaluation
ANN = Path("results/mag_annotate/")
GTDBTK = ANN / "gtdbtk/"
QUAST = ANN / "quast/"
CAMPER = ANN / "camper/"
DRAM = ANN / "dram/"
DRAMMAG = ANN / "dram_mags/"
CHECKM = ANN / "checkm2"
BAKTA = ANN / "bakta"
BAKTAMAG = ANN / "bakta_mags"
EGGNOG = ANN / "eggnog"
PHYLOPHLAN = ANN / "phylophlan"
PROTEINORTHO = ANN / "proteinortho"
SYLPH = ANN / "sylph"

# contig annotation
CONTIG = Path("results/contig_annotate/")
CONTIG_CAMPER = CONTIG / "camper"
CONTIG_DIAMOND = CONTIG / "diamond"
CONTIG_HMMER = CONTIG / "hmmer"
CONTIG_NCYC = CONTIG / "ncyc"
CONTIG_PRODIGAL = CONTIG / "prodigal"
CONTIG_EGGNOG = CONTIG / "eggnog"
CONTIG_EGGNOG7 = CONTIG / "eggnog7"
CONTIG_SYLPH = CONTIG / "sylph"
CONTIG_FEATURECOUNTS = CONTIG / "featurecounts"


# reports
REPORT = Path("reports/")
PIPELINE_REPORT = Path("Rreports/")
REPORT_STEP = REPORT / "step/"
REPORT_SAMPLE = REPORT / "library/"
