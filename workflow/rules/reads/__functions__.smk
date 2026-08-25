def _reads_sample_row(wildcards):
    """Look up the samples.tsv row matching a sample/library wildcard pair"""
    matches = samples.query(
        "sample_id == @wildcards.sample and library_id == @wildcards.library"
    )
    return matches.iloc[0]


def get_forward(wildcards):
    """Path to the forward FASTQ listed in samples.tsv for this sample/library"""
    return _reads_sample_row(wildcards)["forward_filename"]


def get_reverse(wildcards):
    """Path to the reverse FASTQ listed in samples.tsv for this sample/library"""
    return _reads_sample_row(wildcards)["reverse_filename"]
