def get_sample_and_library_from_assembly_id(assembly_id):
    """(sample_id, library_id) pairs whose reads feed into a given assembly_id"""
    subset = samples.loc[samples["assembly_id"] == assembly_id, ["sample_id", "library_id"]]
    return list(subset.itertuples(index=False, name=None))


def _reads_for_assembly(wildcards, end):
    """Per-library read files for one assembly, post host-decontamination if configured"""
    assert end in (1, 2)
    pairs = get_sample_and_library_from_assembly_id(wildcards.assembly_id)
    if HOST_NAMES:
        return [
            PRE_BOWTIE2 / "decontaminated_reads" / f"{sample_id}.{library_id}_{end}.fq.gz"
            for sample_id, library_id in pairs
        ]
    return [FASTP / f"{sample_id}.{library_id}_{end}.fq.gz" for sample_id, library_id in pairs]


def get_forwards_from_assembly_id(wildcards):
    """Forward read files contributing to one assembly"""
    return _reads_for_assembly(wildcards, end=1)


def get_reverses_from_assembly_id(wildcards):
    """Reverse read files contributing to one assembly"""
    return _reads_for_assembly(wildcards, end=2)


def _join_reads(wildcards, end, sep):
    return sep.join(str(path) for path in _reads_for_assembly(wildcards, end=end))


def aggregate_forwards_for_megahit(wildcards):
    """Forward reads, comma-joined as megahit expects for multiple libraries"""
    return _join_reads(wildcards, end=1, sep=",")


def aggregate_reverses_for_megahit(wildcards):
    """Reverse reads, comma-joined as megahit expects for multiple libraries"""
    return _join_reads(wildcards, end=2, sep=",")


def aggregate_forwards_for_metaspades(wildcards):
    """Forward reads, space-joined as metaspades expects for multiple libraries"""
    return _join_reads(wildcards, end=1, sep=" ")


def aggregate_reverses_for_metaspades(wildcards):
    """Reverse reads, space-joined as metaspades expects for multiple libraries"""
    return _join_reads(wildcards, end=2, sep=" ")


# The binners (CONCOCT, MetaBAT2, MaxBin2) work off read alignments to the assembly,
# not the raw reads themselves.
def get_alignments_from_assembly_id(wildcards):
    """BAM/CRAM alignment file for every library that makes up one assembly"""
    pairs = get_sample_and_library_from_assembly_id(wildcards.assembly_id)
    return [
        ASSEMBLE_BOWTIE2 / f"{wildcards.assembly_id}.{sample_id}.{library_id}.{ALIGN_EXT}"
        for sample_id, library_id in pairs
    ]


def get_alignment_indexes_from_assembly_id(wildcards):
    """Index file (.bai/.crai) matching each alignment file"""
    index_ext = ".bai" if ALIGN_EXT == "bam" else ".crai"
    return [f"{aln}{index_ext}" for aln in get_alignments_from_assembly_id(wildcards)]


def compose_bams_for_metabat2_run(wildcards):
    """Per-library BAM paths that metabat2's run rule converts alignments into"""
    pairs = get_sample_and_library_from_assembly_id(wildcards.assembly_id)
    return [
        METABAT2 / f"{wildcards.assembly_id}.{sample_id}.{library_id}.bam"
        for sample_id, library_id in pairs
    ]
