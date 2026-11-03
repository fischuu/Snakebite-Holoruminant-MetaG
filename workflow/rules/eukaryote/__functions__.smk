# 4CAC refines its labels on the metaSPAdes assembly graph, which only the metaspades rule
# keeps (inside its tarball). MEGAHIT and self-provided assemblies have no graph it can read.
FOURCAC_SUPPORTED = config["assembler"] == "metaspades"
if not FOURCAC_SUPPORTED:
    debug(f"4CAC needs a metaSPAdes assembly graph; skipped for assembler '{config['assembler']}'")


def compose_coverage_args_for_remag(wildcards):
    """One --coverage option per alignment of the assembly (one alignment = one sample for REMAG)"""
    return " ".join(f"--coverage {aln}" for aln in assembly_alignments(wildcards))
