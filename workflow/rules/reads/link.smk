rule reads__link__run:
    """Symlink one sample's raw reads under a normalized {sample}.{library}_{1,2}.fq.gz name"""
    input:
        forward_=get_forward,
        reverse_=get_reverse,
    output:
        forward_=READS / "{sample}.{library}_1.fq.gz",
        reverse_=READS / "{sample}.{library}_2.fq.gz",
    log:
        READS / "{sample}.{library}.log"
    benchmark:
        READS / "benchmark/{sample}.{library}.tsv"
    container:
        docker["reads"]
    shell:
        """
        exec > {log} 2>&1
        for pair in "{input.forward_}:{output.forward_}" "{input.reverse_}:{output.reverse_}"; do
            src=${{pair%%:*}}
            dst=${{pair#*:}}
            ln --symbolic "$(readlink --canonicalize "$src")" "$dst"
        done
        """

rule reads__link:
    """Symlink every sample/library's raw reads listed in samples.tsv"""
    input:
        [
            READS / f"{sample}.{library}_{end}.fq.gz"
            for sample, library in SAMPLE_LIBRARY
            for end in (1, 2)
        ],
