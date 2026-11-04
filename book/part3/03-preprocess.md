# Module `preprocess` {#sec-module-preprocess}

Raw reads aren't ready for analysis. They contain adapter sequence, bases of poor quality, and in samples from an animal many reads that come from the animal itself. This module removes all of that. Its result, the clean reads, is the input of nearly everything that follows.

```bash
bash run_Snakebite-Holoruminant-MetaG.sh preprocess
```

## The flow

```
results/reads/S.L_{1,2}.fq.gz
        │  preprocess__fastp__run
        ▼
results/preprocess/fastp/S.L_{1,2}.fq.gz
        │  preprocess__bowtie2__map                  (first host)
        ▼
results/preprocess/bowtie2/bovine/S.L.cram
        │  preprocess__bowtie2__extract_nonhost__run
        ▼
results/preprocess/bowtie2/nonbovine/S.L_{1,2}.fq.gz
        │  preprocess__bowtie2__map                  (next host)
        ▼
       ...
        │  preprocess__store_final_fastq
        ▼
results/preprocess/bowtie2/decontaminated_reads/S.L_{1,2}.fq.gz  (the clean reads)
```

With no hosts in `features.yaml`, the arrow goes directly from fastp to the clean reads. The name of the last folder comes from the constant `CLEAN_READS` in `folders.smk`, as all paths do in this pipeline. `S.L` stands for `{sample_id}.{library_id}`, which the constant `LIBRARY` holds.

## Trimming: `preprocess__fastp__run`

This rule runs fastp on one library, and @sec-tool-fastp explains the tool. This is the core of the rule:

```bash
fastp \
    --in1 {input.forward_} --in2 {input.reverse_} \
    --out1 {params.work_prefix}_1.fq --out2 {params.work_prefix}_2.fq \
    --unpaired1 {params.work_prefix}_u1.fq --unpaired2 {params.work_prefix}_u2.fq \
    --html {output.html} --json {output.json} \
    --verbose \
    --adapter_sequence {params.adapter_forward} \
    --adapter_sequence_r2 {params.adapter_reverse} \
    --length_required {params.length_required} \
    --thread {threads} \
    {params.extra}
```

The adapters come from `samples.tsv`, through the functions `get_forward_adapter` and `get_reverse_adapter`. The other options come from `params.yaml`:

| Option | Default | Meaning |
|--------|---------|---------|
| `preprocess: fastp: length_required` | 25 | Throw away reads that are shorter than this after trimming. Nonpareil needs at least 25 bases |
| `preprocess: fastp: extra` | `--trim_poly_g --trim_poly_x` | Further options, here for removing tails of a single base, which two-color sequencers tend to produce |

Note that fastp first writes uncompressed files. After that, the rule compresses them with `bgzip`, one by one, and tests each file:

```bash
bgzip --compress-level 9 --threads {threads} {params.work_prefix}_${{suffix}}.fq
mv {params.work_prefix}_${{suffix}}.fq.gz "${{dest[$suffix]}}"
gzip --test "${{dest[$suffix]}}"
```

fastp can only use a limited number of threads for its own compression, and `bgzip` is faster here. Only a file that passed the test gets its final name, so if anything fails along the way, the rule fails and you don't get a broken file.

The doubled braces are needed because Snakemake reads single braces as its own placeholders, as @sec-first-rule explains. They turn into normal Bash variables when the command runs.

The log uses the pattern of @sec-pipeline-patterns: it's first written to `{log}.try{resources.attempt}`, and only a successful run moves it to `{log}`.

`preprocess__fastp` is the target, and it asks for the outcome of all libraries.

### What you get

| File | Content |
|------|---------|
| `S.L_1.fq.gz`, `S.L_2.fq.gz` | Read pairs that both passed |
| `S.L_u1.fq.gz`, `S.L_u2.fq.gz` | Reads whose mate was thrown away. They aren't used later |
| `S.L_fastp.html` | Report for a browser |
| `S.L_fastp.json` | The same as data |

## Removing host reads

The pipeline maps the reads against each host genome in turn, and it keeps only the reads that don't map. @sec-tool-bowtie2 explains the mapping.

### `preprocess__bowtie2__build`

Bowtie2 needs an index of each genome, and this rule builds it once per host:

```bash
bowtie2-build --threads {threads} {input.genome} {output.index}
```

The index consists of several files that share the prefix `{output.index}`. Snakemake can't easily follow this, so the rule says `index=touch(HOST_INDEX / "{genome}")`. This makes an empty file with the name of the prefix, and all other rules depend on that file. @sec-file-flags explains `touch`.

### `preprocess__bowtie2__map`

This rule maps one library to one host:

```bash
bowtie2 --threads {threads} --rg-id '{params.rg_id}' --rg '{params.rg_extra}' \
        -x {input.index} -1 {input.forward_} -2 {input.reverse_} \
    | samtools sort -@ {threads} -m {params.sort_memory} -l 9 -M --reference {input.genome} \
        -o {output.cram} -
samtools idxstats {output.cram} | awk '{{print $1, $3}}' > {output.counts}
```

Which reads come in depends on the position of the host. The function `reads_for_host_mapping` looks at the order in `HOST_NAMES`: the first host gets fastp's reads, and all others get what the host before left. This is what the output of Snakemake's dry run shows as a chain of jobs, and @sec-chaining explains why it just works: each rule asks for its input, and Snakemake finds the rule that makes it.

The read group options `--rg-id` and `--rg` mark the reads with their library and sample, built by `compose_rg_id` and `compose_rg_extra`. `samtools sort` gets `-M`, which places unmapped reads next to each other according to similarity, and this compresses them better. The output is a CRAM file because of its extension, and CRAM needs the reference sequence, hence `--reference`.

The result in `.chr_alignment_counts.tsv` is a simple count of the reads per chromosome.

The CRAM is marked `temp()` because nothing later needs it, and Snakemake removes it as soon as the rules that read it are finished.

One option in `params.yaml` applies here:

| Option | Default | Meaning |
|--------|---------|---------|
| `preprocess: bowtie2: samtools: mem_per_thread` | `1G` | Memory for `samtools sort`, **per thread** |

Make sure that this memory, multiplied by the threads, fits into the job and leaves room for Bowtie2. It can be a reason for a job to be killed.

The line with `find ... -delete` before the mapping removes temporary files of an earlier attempt, as they would disturb `samtools sort`.

### `preprocess__bowtie2__extract_nonhost__run`

This rule writes the reads that didn't map to FASTQ:

```bash
samtools view -u -f 12 -T {input.genome} {input.cram} \
    | samtools sort -n -l 0 -m 500M -@ {threads} -T {params.sort_tmpdir} \
    | samtools fastq -N -0 /dev/null -c 9 -@ {threads} \
        -1 {output.forward_} \
        -2 {output.reverse_}
```

Reading it from left to right:

- `-f 12` keeps reads with both flags 4 and 8, meaning that the read and its mate are both unmapped. A pair in which only one mate maps is treated as host and removed. This is the careful choice, and it loses a few real microbial reads.
- `samtools sort -n` sorts by name, because `samtools fastq` needs the two mates next to each other.
- `samtools fastq` writes the two files. `-N` adds `/1` and `/2` to the names, and `-0 /dev/null` throws away reads that lack this information. It compresses them by itself, because the names end in `.gz`, and `-c 9` sets the level.

Until version 0.4.69, this rule wrote through `>(pigz ...)`, and this could cut off the files, as @sec-process-substitution-trap explains. If you have clean reads from an earlier version, check them as `RELEASE_NOTES` describes.

These FASTQ files are temporary as well, as long as they aren't the last of the chain.

### `preprocess__store_final_fastq`

This rule copies the reads at the end of the chain to the place of the clean reads. `reads_after_last_host` finds them. With no hosts, these are fastp's reads.

`preprocess__bowtie2__extract_nonhost` asks for these files for all libraries, and `preprocess__bowtie2` is the target of the whole chain.

Since each host removes reads before the next one sees them, you can read how many reads were lost at each step from the sizes of the FASTQ reports, or from `samtools stats` below.

## Checking the result

### `preprocess__samtools__stats_cram`

This rule writes `samtools stats` for each mapping, and `preprocess__samtools` asks for these files and for the `flagstats` of the generic rule `helpers__samtools__flagstats_cram`. @sec-tool-samtools explains them. `flagstats` tells you quickly how many reads mapped to a host. In rumen samples, you would expect a share of cow reads, and hardly any human ones. A high human share points to contamination in the lab. The share of each host is a result in its own right.

### `preprocess__fastqc__fastp` and `preprocess__fastqc__nonhost`

These two rules ask for FastQC reports of the reads after fastp and after each host. `preprocess__fastqc` is the target for both. `helpers__fastqc` does the real work. Compare the report before and after trimming, and you see if the adapters are gone.

## Things to look at after a run

1. How many reads did fastp keep? The JSON or the HTML report has it. Losing a few percent is normal. Losing half is not.
2. Are the adapters gone? Look at the FastQC report after fastp.
3. How many reads mapped to each host? Look at `flagstats`.
4. How many clean reads does each sample have? A sample with far fewer than the others will produce less of everything later on.

## Summary

- fastp trims the reads with the adapters from the sample table.
- Bowtie2 maps them against each host in turn, and only pairs with both mates unmapped go on.
- The order of the hosts in `features.yaml` decides the order of the chain.
- The clean reads at the end are what all later modules read.
- Temporary CRAM and FASTQ files of the chain are removed automatically.
