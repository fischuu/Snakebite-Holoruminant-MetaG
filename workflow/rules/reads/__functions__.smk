def _reads_sample_row(wildcards):
    """Look up the samples.tsv row matching a sample/library wildcard pair"""
    # samples is exploded by assembly_id, so a library in several assemblies has one
    # otherwise identical row per assembly
    matches = (
        samples.query("sample_id == @wildcards.sample and library_id == @wildcards.library")
        .drop(columns="assembly_id")
        .drop_duplicates()
    )
    if len(matches) != 1:
        raise ValueError(
            f"Expected exactly one samples.tsv row for sample={wildcards.sample!r}, "
            f"library={wildcards.library!r}; found {len(matches)}"
        )
    return matches.iloc[0]


def get_forward(wildcards):
    """Path to the forward FASTQ listed in samples.tsv for this sample/library"""
    return _reads_sample_row(wildcards)["forward_filename"]


def get_reverse(wildcards):
    """Path to the reverse FASTQ listed in samples.tsv for this sample/library"""
    return _reads_sample_row(wildcards)["reverse_filename"]
