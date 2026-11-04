# Module `quantify` {#sec-module-quantify}

Now that there is a catalogue of genomes, we can ask how much of each genome is in each sample. The module maps the clean reads of every library against the catalogue, and it counts. The result is the table you will most likely use for your statistics: one row per MAG and one column per sample.

```bash
bash run_Snakebite-Holoruminant-MetaG.sh quantify
```

## Why map to a catalogue

You could count from the assembly-specific mappings of the module `assemble`, but these are not comparable. In this module, all libraries of all samples are mapped to the same reference, the catalogue. So a value for a genome means the same thing in every sample, including samples that weren't part of the assembly of that genome.

There's also a limit to keep in mind: only what is in the catalogue can be counted. Reads of organisms without a MAG don't appear here. The share of reads that do map tells you how much of the community your catalogue represents. In a complex rumen sample, it's common that a good part of the reads doesn't map.

## The flow

```
results/assemble/drep/dereplicated_genomes.fa.gz
        │  quantify__bowtie2__build
        ▼
results/quantify/index/dereplicated_genomes
        │  quantify__bowtie2__map, with the clean reads of each library
        ▼
results/quantify/bowtie2/{sample_id}.{library_id}.cram
        │  quantify__coverm__genome__run, quantify__coverm__contig_one
        ▼
results/quantify/coverm/{genome,contig}/{method}/{sample_id}.{library_id}.tsv
        │  quantify__coverm__genome_aggregate, quantify__coverm__contig_aggregate
        ▼
results/quantify/coverm/{genome,contig}.{method}.tsv
```

## Mapping

### `quantify__bowtie2__build`

This rule indexes the catalogue once.

### `quantify__bowtie2__map`

```bash
bowtie2 --threads {threads} --rg-id '{params.rg_id}' --rg '{params.rg_extra}' \
        -x {input.index} -1 {input.forward_} -2 {input.reverse_} \
    | samtools sort -@ {threads} -m {params.sort_memory} -l 9 -M --reference {input.catalogue} \
        -o {output} -
```

This is the same pattern as in the module `preprocess`, with the same explanation of the options. The target `quantify__bowtie2` asks for one CRAM per library. Since this file is the basis of everything else in this module, it isn't temporary.

| Option | Default | Meaning |
|--------|---------|---------|
| `quantify: samtools: mem` | `1G` | Memory for `samtools sort`, per thread |

`quantify__samtools__stats_cram` writes `samtools stats` of each mapping, and `quantify__samtools` asks for these files and for `flagstats`. **Look at the mapping rate first**, as this is the share of your reads that the catalogue can explain.

## Counting

@sec-tool-coverm explains the tool and its measures. The rules run once per library and per method.

### `quantify__coverm__genome__run`

```bash
samtools view -1 -F 4 -T {input.catalogue} {input.alignment} \
    | coverm genome -b /dev/stdin -m {wildcards.method} -s {params.settings[separator]} \
        --min-covered-fraction {params.settings[min_covered_fraction]} \
    > {output}
```

`samtools view -F 4` passes on the mapped reads as BAM, since CoverM can't read CRAM. `-s @` is why contig names have their special format: CoverM takes everything before the `@` as the name of the genome, so `ERR2019410:bin_00012@contig_00000001` counts for the genome `ERR2019410:bin_00012`. This way the catalogue doesn't need a separate list of which contig belongs to which genome.

### `quantify__coverm__genome_aggregate`

This rule joins the tables of all libraries into one, using `workflow/scripts/coverm_wide_table.R`, with the MAGs as rows and the libraries as columns. The target for all methods is `quantify__coverm__genome`.

### `quantify__coverm__contig_one`

```bash
samtools view -1 -F 4 -T {input.catalogue} {input.alignment} \
    | coverm contig -b /dev/stdin -m {wildcards.method} --proper-pairs-only \
    > {output}
```

The same on the level of contigs. Note `--proper-pairs-only`, which counts only reads whose mate maps as expected. The genome-level rule doesn't use this option, so the two levels don't add up exactly.

### `quantify__coverm__contig_aggregate` and `quantify__coverm__contig`

These do the same as on the genome level. `quantify__coverm` asks for both levels.

## The options

| Option | Default | Meaning |
|--------|---------|---------|
| `quantify: coverm: genome: methods` | `count`, `covered_bases`, `length`, `tpm` | Which measures to compute, each gives its own table |
| `quantify: coverm: genome: min_covered_fraction` | 0.0 | Report a genome only if this share of it is covered |
| `quantify: coverm: genome: separator` | `@` | What separates genome and contig in a name |
| `quantify: coverm: contig: methods` | `count`, `covered_bases`, `length`, `tpm` | The same for contigs |

**About `min_covered_fraction`:** with 0.0, a genome counts as present with a single read. CoverM's own default is higher, because a few reads can map to a genome that isn't really there, for example through a conserved gene. With this setting, you have to do this filtering yourself. The table `covered_bases` divided by `length` gives you the share of each genome that is covered, and this is the basis for it.

## What you get

| File in `results/quantify/coverm/` | Content | Use it for |
|------|---------|---------|
| `genome.count.tsv` | Reads per MAG and library | Statistics for differential abundance |
| `genome.tpm.tsv` | Reads normalized for genome length and depth | Comparing MAGs within a sample |
| `genome.covered_bases.tsv` | Covered bases | Filtering, see above |
| `genome.length.tsv` | Length of each MAG | Normalizing |
| `contig.*.tsv` | The same per contig | Details within a genome |

Note that a value of TPM is relative: the sum over a sample is fixed, and it covers the mapped reads only. Comparing it between samples tells you about the shares, not the absolute amount.

## Summary

- All libraries are mapped to the same catalogue, so the values are comparable between samples.
- Only organisms with a MAG are counted, so check the share of mapped reads.
- `genome.count.tsv` and `genome.tpm.tsv` are the main results.
- With the default `min_covered_fraction`, you have to filter weakly covered genomes yourself.
