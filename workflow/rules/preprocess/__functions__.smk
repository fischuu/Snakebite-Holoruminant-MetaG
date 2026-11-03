# fastp
def _sample_row(wildcards):
    """Look up the samples.tsv row matching a sample/library wildcard pair"""
    # samples is exploded by assembly_id, so a library in several assemblies has one
    # otherwise identical row per assembly
    matches = (
        samples.query("sample_id == @wildcards.sample_id and library_id == @wildcards.library_id")
        .drop(columns="assembly_id")
        .drop_duplicates()
    )
    if len(matches) != 1:
        raise ValueError(
            f"Expected exactly one samples.tsv row for sample_id={wildcards.sample_id!r}, "
            f"library_id={wildcards.library_id!r}; found {len(matches)}"
        )
    return matches.iloc[0]


def get_forward_adapter(wildcards):
    """Forward adapter sequence listed in samples.tsv for this sample/library"""
    return _sample_row(wildcards)["forward_adapter"]


def get_reverse_adapter(wildcards):
    """Reverse adapter sequence listed in samples.tsv for this sample/library"""
    return _sample_row(wildcards)["reverse_adapter"]


# bowtie2
def compose_rg_id(wildcards):
    """Read-group ID for a bowtie2 alignment"""
    return f"{wildcards.sample_id}_{wildcards.library_id}"


def compose_rg_extra(wildcards):
    """Read-group tags (library/platform/sample) for a bowtie2 alignment"""
    tag = f"{wildcards.sample_id}_{wildcards.library_id}"
    return f"LB:{tag}\tPL:Illumina\tSM:{wildcards.sample_id}"


def _reads_left_by_host(genome):
    """Folder of the reads that did not map to one host"""
    return HOST_MAPPING / f"non{genome}"


def _mate_file(folder, wildcards, end):
    return folder / f"{wildcards.sample_id}.{wildcards.library_id}_{end}.fq.gz"


def reads_for_host_mapping(end):
    """Function giving one mate's reads that enter the mapping against one host

    Decontamination is a chain: each host gets the reads the host before it left over, and
    the first host gets fastp's reads.
    """
    def reads(wildcards):
        position = HOST_NAMES.index(wildcards.genome)
        folder = _reads_left_by_host(HOST_NAMES[position - 1]) if position else FASTP
        return _mate_file(folder, wildcards, end)

    return reads


def reads_after_last_host(end):
    """Function giving one mate's reads at the end of that chain (fastp's reads without any host)"""
    def reads(wildcards):
        folder = _reads_left_by_host(HOST_NAMES[-1]) if HOST_NAMES else FASTP
        return _mate_file(folder, wildcards, end)

    return reads
