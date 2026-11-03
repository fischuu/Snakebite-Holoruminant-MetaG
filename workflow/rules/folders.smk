# Generate more configuration keys
# Define the script_folder dynamically based on the pipeline_folder
SCRIPT_FOLDER = os.path.join(config["pipeline_folder"], "workflow", "scripts")

READS = Path("results/reads")
WD = os.getcwd()

# reference
REFERENCE = Path("results/reference")
HOST_GENOMES = REFERENCE / "hosts"

# preprocess
PREPROCESS = Path("results/preprocess")
FASTP = PREPROCESS / "fastp"
HOST_INDEX = PREPROCESS / "index"
HOST_MAPPING = PREPROCESS / "bowtie2"
HOST_COUNTS = PREPROCESS / "quantification"

# read_annotate
READ_ANNOT = Path("results/read_annotate")
NONPAREIL = READ_ANNOT / "nonpareil"
METAPHLAN = READ_ANNOT / "metaphlan"
HUMANN = READ_ANNOT / "humann"
PHYLOFLASH = READ_ANNOT / "phyloflash"
SINGLEM = READ_ANNOT / "singlem"
PRE_COVERM = READ_ANNOT / "coverm"
KRAKEN2 = READ_ANNOT / "kraken2"
KRONA = READ_ANNOT / "krona"
DIAMOND = READ_ANNOT / "diamond"
PRE_SYLPH = READ_ANNOT / "sylph"
NCYC = READ_ANNOT / "ncyc"

# assemble
ASSEMBLE = Path("results/assemble")
MEGAHIT = ASSEMBLE / "megahit"
METASPADES = ASSEMBLE / "metaspades"
ASSEMBLY_INDEX = ASSEMBLE / "index"
ASSEMBLY_MAPPING = ASSEMBLE / "bowtie2"
CONCOCT = ASSEMBLE / "concoct"
METABAT2 = ASSEMBLE / "metabat2"
MAXBIN2 = ASSEMBLE / "maxbin2"
MAGSCOT = ASSEMBLE / "magscot"
PRODIGAL = MAGSCOT / "prodigal"
DREP = ASSEMBLE / "drep"

# quantify
QUANTIFY = Path("results/quantify")
MAG_INDEX = QUANTIFY / "index"
MAG_MAPPING = QUANTIFY / "bowtie2"
COVERM = QUANTIFY / "coverm"

# mag_annotate
MAG_ANNOT = Path("results/mag_annotate")
GTDBTK = MAG_ANNOT / "gtdbtk"
QUAST = MAG_ANNOT / "quast"
CAMPER = MAG_ANNOT / "camper"
DRAM = MAG_ANNOT / "dram"
DRAMMAG = MAG_ANNOT / "dram_mags"
CHECKM2 = MAG_ANNOT / "checkm2"
BAKTA = MAG_ANNOT / "bakta"
BAKTAMAG = MAG_ANNOT / "bakta_mags"
EGGNOG = MAG_ANNOT / "eggnog"
PHYLOPHLAN = MAG_ANNOT / "phylophlan"
PROTEINORTHO = MAG_ANNOT / "proteinortho"
SYLPH = MAG_ANNOT / "sylph"

# contig annotation
CONTIG = Path("results/contig_annotate")
CONTIG_CAMPER = CONTIG / "camper"
CONTIG_DIAMOND = CONTIG / "diamond"
CONTIG_HMMER = CONTIG / "hmmer"
CONTIG_NCYC = CONTIG / "ncyc"
CONTIG_PRODIGAL = CONTIG / "prodigal"
CONTIG_EGGNOG = CONTIG / "eggnog"
CONTIG_EGGNOG7 = CONTIG / "eggnog7"
CONTIG_SYLPH = CONTIG / "sylph"
CONTIG_FEATURECOUNTS = CONTIG / "featurecounts"

# eukaryote
EUK = Path("results/eukaryote")
EUK_TIARA = EUK / "tiara"
EUK_4CAC = EUK / "4cac"
EUK_REMAG = EUK / "remag"

# reports
PIPELINE_REPORT = Path("Rreports")

# Files that several rules or modules read, so that each path is only spelled out once
LIBRARY = "{sample_id}.{library_id}"

HOST_FASTA = HOST_GENOMES / "{genome}.fa.gz"
HOST_FAI = HOST_GENOMES / "{genome}.fa.gz.fai"
HOST_CRAM = HOST_MAPPING / "{genome}" / f"{LIBRARY}.cram"
HOST_CRAI = HOST_MAPPING / "{genome}" / f"{LIBRARY}.cram.crai"

CLEAN_READS = HOST_MAPPING / "decontaminated_reads"
CLEAN_FORWARD = CLEAN_READS / f"{LIBRARY}_1.fq.gz"
CLEAN_REVERSE = CLEAN_READS / f"{LIBRARY}_2.fq.gz"

# Contigs of one assembly: a pipeline assembler writes them here, self-provided ones are expected here
CONTIGS = ASSEMBLE / config["assembler"] / "{assembly_id}.fa.gz"

MAG_GENOMES = DREP / "dereplicated_genomes"
MAG_CATALOGUE = DREP / "dereplicated_genomes.fa.gz"
MAG_CATALOGUE_FAI = DREP / "dereplicated_genomes.fa.gz.fai"
MAG_CRAM = MAG_MAPPING / f"{LIBRARY}.cram"
MAG_CRAI = MAG_MAPPING / f"{LIBRARY}.cram.crai"
