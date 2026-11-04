# Modules `reads` and `reference` {#sec-module-reads}

These two modules do the preparation. They are short, and they are a good first look at how the rules of the pipeline work.

## What they are for

Every project names its files differently. The module `reads` makes one consistent set of names, so that all later rules can rely on them, and it checks the quality of the raw reads.

The module `reference` prepares the host genomes in the compressed format that the mapping tools need.

## The module `reads`

```bash
bash run_Snakebite-Holoruminant-MetaG.sh reads
```

This runs two steps per library.

### `reads__link__run`: one consistent name

This rule looks up the two read files of a library in `samples.tsv`, and links them to a fixed name:

```
results/reads/{sample}.{library}_1.fq.gz
results/reads/{sample}.{library}_2.fq.gz
```

The inputs come from the functions `get_forward` and `get_reverse`. They take the wildcards and look up the row of the sample table, as @sec-python explains. Both functions use `_reads_sample_row`, which raises a clear error if it doesn't
find exactly one row.

The command is only this:

```bash
ln --symbolic "$(readlink --canonicalize {input.forward_})" {output.forward_}
ln --symbolic "$(readlink --canonicalize {input.reverse_})" {output.reverse_}
```

`readlink --canonicalize` turns the path into an absolute one first. Otherwise the link would point to a relative path, and it would be wrong as seen from `results/reads/`. No data is copied, so this step takes no time and no space, and all
later rules read the original files. This also means that the target of the link must remain in place and that it must be visible in the containers.

`reads__link` is the target of this step, and it asks for the links of all libraries.

### `reads__fastqc`: first look at the quality

`reads__fastqc` asks for a report on each read file:

```
results/reads/{sample}.{library}_{1,2}_fastqc.zip
```

It has no command of its own. The rule that produces these files is the generic `helpers__fastqc` from @sec-module-helpers, which works for any `.fq.gz` file. @sec-tool-fastqc explains how to read the report.

Look at these reports before you go on. They tell you the read length, whether adapters are present and how the quality falls along the reads. This is what you need to judge the next step.

### What you get

| File | Content |
|------|---------|
| `{sample}.{library}_1.fq.gz`, `_2.fq.gz` | Links to your reads |
| `{sample}.{library}_{1,2}_fastqc.html` | The report to open in a browser |
| `{sample}.{library}_{1,2}_fastqc.zip` | The same as data |
| `{sample}.{library}.log`, `benchmark/` | Log and resource use of the link step |

## The module `reference` {#sec-module-reference}

```bash
bash run_Snakebite-Holoruminant-MetaG.sh reference
```

### `reference__hosts__recompress`

The host genomes are listed in `features.yaml`, and they usually come compressed with `gzip`. Some steps have to jump to a certain position in the genome, and this is impossible in a normal `gzip` file: you would have to read everything from the start.
BGZF, which `bgzip` writes, solves this by compressing in small blocks. A BGZF file is still a valid gzip file, so all tools can read it, and with an index they can jump to any place.

So this rule uncompresses each genome and compresses it again:

```bash
zcat {input} | bgzip -@ {threads} > {output}
```

The result is `results/reference/hosts/{genome}.fa.gz`, where `{genome}` is the name you chose in `features.yaml`. The input path is looked up with a function again:

```python
input:
    lambda wildcards: features["hosts"][wildcards.genome],
```

`reference__hosts` asks for one such file per host, and `reference` asks for all of them. Since you rarely change the genomes, and this is the same for all projects, this module usually runs only once per project.

The index files `.fai` and `.gzi` aren't made here. The generic rule `helpers__samtools__faidx_fagz` makes them when a later rule asks for them.

## Summary

- `reads` links your files to the names `{sample}.{library}_{1,2}.fq.gz` and runs FastQC on them.
- `reference` recompresses the host genomes with `bgzip`.
- Neither module needs a database, so they are a cheap first test of a new setup.
