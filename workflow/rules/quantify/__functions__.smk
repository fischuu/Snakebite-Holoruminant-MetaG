def _coverm_tsvs(mode, method):
    """Per-sample/library CoverM TSV paths for a given aggregation mode and method"""
    return [
        COVERM / mode / method / f"{sample_id}.{library_id}.tsv"
        for sample_id, library_id in SAMPLE_LIBRARY
    ]


def get_tsvs_for_dereplicate_coverm_genome(wildcards):
    """TSVs to merge for the genome-level CoverM aggregation rule"""
    return _coverm_tsvs(mode="genome", method=wildcards.method)


def get_tsvs_for_dereplicate_coverm_contig(wildcards):
    """TSVs to merge for the contig-level CoverM aggregation rule"""
    return _coverm_tsvs(mode="contig", method=wildcards.method)
