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


# Host decontamination is a chain: each host's input is the previous host's
# "non-host" output, and the very first host reads straight from fastp.
def _host_chain_input(wildcards, end):
    """Reads feeding into the mapping step for one host in the decontamination chain"""
    assert end in (1, 2)
    step = HOST_NAMES.index(wildcards.genome)
    if step == 0:
        return FASTP / f"{wildcards.sample_id}.{wildcards.library_id}_{end}.fq.gz"
    previous_host = HOST_NAMES[step - 1]
    return (
        PRE_BOWTIE2
        / f"non{previous_host}"
        / f"{wildcards.sample_id}.{wildcards.library_id}_{end}.fq.gz"
    )


def get_input_forward_for_host_mapping(wildcards):
    """Forward reads feeding into one host-mapping step"""
    return _host_chain_input(wildcards, end=1)


def get_input_reverse_for_host_mapping(wildcards):
    """Reverse reads feeding into one host-mapping step"""
    return _host_chain_input(wildcards, end=2)


# The final, fully decontaminated (or fastp-only, if no hosts configured) reads
def _final_preprocessed_reads(wildcards, end):
    assert end in (1, 2)
    if not HOST_NAMES:
        return FASTP / f"{wildcards.sample_id}.{wildcards.library_id}_{end}.fq.gz"
    return (
        PRE_BOWTIE2
        / f"non{HOST_NAMES[-1]}"
        / f"{wildcards.sample_id}.{wildcards.library_id}_{end}.fq.gz"
    )


def get_final_forward_from_pre(wildcards):
    """Forward reads after the full preprocessing chain"""
    return _final_preprocessed_reads(wildcards, end=1)


def get_final_reverse_from_pre(wildcards):
    """Reverse reads after the full preprocessing chain"""
    return _final_preprocessed_reads(wildcards, end=2)
