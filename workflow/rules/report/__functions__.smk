def get_stats_files_from_sample_and_library_ids(wildcards):
    """Every per-sample/library QC and mapping-stats file that feeds the sample report"""
    sample_id, library_id = wildcards.sample_id, wildcards.library_id
    sections = []

    sections.append(
        [READS / f"{sample_id}.{library_id}_{end}_fastqc.zip" for end in (1, 2)]
    )
    sections.append(
        [
            FASTP / f"{sample_id}.{library_id}_{end}_fastqc.zip"
            for end in ("1", "2", "u1", "u2")
        ]
    )
    sections.append([FASTP / f"{sample_id}.{library_id}_fastp.html"])

    if HOST_NAMES:
        sections.append(
            [
                PRE_BOWTIE2 / genome / f"{sample_id}.{library_id}.{ext}"
                for genome in HOST_NAMES
                for ext in ("stats.txt", "flagstats.txt", "idxstats.tsv")
            ]
        )
        sections.append(
            [
                PRE_BOWTIE2 / f"non{genome}" / f"{sample_id}.{library_id}_{end}_fastqc.zip"
                for genome in HOST_NAMES
                for end in (1, 2)
            ]
        )

    sections.append(
        [
            KRAKEN2 / kraken_db / f"{sample_id}.{library_id}.report"
            for kraken_db in KRAKEN2_DBS
        ]
    )
    sections.append(
        [
            QUANT_BOWTIE2 / f"{sample_id}.{library_id}.{ext}"
            for ext in ("stats.txt", "flagstats.txt")
        ]
    )

    return [str(path) for section in sections for path in section]
