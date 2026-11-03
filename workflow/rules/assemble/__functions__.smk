# Read alignments against an assembly are stored as BAM or CRAM, see params.yaml
SAMTOOLS_OUTTYPE = params["assemble"]["samtools"]["out_type"].upper()
assert SAMTOOLS_OUTTYPE in {"BAM", "CRAM"}, "params['assemble']['samtools']['out_type'] must be BAM or CRAM"
ALIGN_EXT = SAMTOOLS_OUTTYPE.lower()


def libraries_of_assembly(assembly_id):
    """(sample_id, library_id) of every library in one assembly"""
    members = samples[samples["assembly_id"] == assembly_id]
    return list(zip(members["sample_id"], members["library_id"]))


def assembly_reads(end, separator=None):
    """Function giving the reads of one mate (1 or 2) for all libraries of an assembly

    These are the decontaminated reads, or fastp's if no host is configured. With a separator
    they come as one string, the way MEGAHIT takes several libraries on its command line.
    """
    read_folder = CLEAN_READS if HOST_NAMES else FASTP

    def reads(wildcards):
        paths = [
            str(read_folder / f"{sample_id}.{library_id}_{end}.fq.gz")
            for sample_id, library_id in libraries_of_assembly(wildcards.assembly_id)
        ]
        return separator.join(paths) if separator else paths

    return reads


def assembly_alignments(wildcards):
    """Alignment of every library against one assembly (the input of the binners)"""
    return [
        ASSEMBLY_MAPPING / f"{wildcards.assembly_id}.{sample_id}.{library_id}.{ALIGN_EXT}"
        for sample_id, library_id in libraries_of_assembly(wildcards.assembly_id)
    ]


def assembly_alignment_indexes(wildcards):
    """Index (.bai or .crai) of every file from assembly_alignments"""
    suffix = ".bai" if ALIGN_EXT == "bam" else ".crai"
    return [f"{alignment}{suffix}" for alignment in assembly_alignments(wildcards)]
