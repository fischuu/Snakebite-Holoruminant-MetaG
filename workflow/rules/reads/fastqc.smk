rule reads__fastqc:
    """Aggregate FastQC reports for every raw forward/reverse read file"""
    input:
        [
            READS / f"{sample_id}.{library_id}_{end}_fastqc.zip"
            for sample_id, library_id in SAMPLE_LIBRARY
            for end in (1, 2)
        ],
