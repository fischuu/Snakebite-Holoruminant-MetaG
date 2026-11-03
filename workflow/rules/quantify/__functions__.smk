def coverm_library_tables(mode):
    """Function giving the per-library CoverM tables of one mode ("genome" or "contig") and method"""
    def tables(wildcards):
        return [
            COVERM / mode / wildcards.method / f"{sample_id}.{library_id}.tsv"
            for sample_id, library_id in SAMPLE_LIBRARY
        ]

    return tables
