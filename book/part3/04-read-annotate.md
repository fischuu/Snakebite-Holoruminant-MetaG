# Module `read_annotate` {#sec-module-read-annotate}

This module asks what is in a sample before anything is assembled: which organisms, how many of each, which functions, and how well the sequencing covered the community. All tools work on the reads directly, and each answers a slightly different question. This is the module that needs the largest databases.

```bash
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate

# Or a single tool:
bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__kraken2
```

## The tools at a glance

| Target | Tool | Answers | Reads it uses |
|--------|------|---------|---------------|
| `read_annotate__kraken2` | @sec-tool-kraken2 | Which taxon does each read belong to? | After fastp |
| `read_annotate__krona` | @sec-tool-krona | Kraken2's answer as an interactive chart | |
| `read_annotate__singlem` | @sec-tool-singlem | Which organisms, from marker genes, and how much of the sample is microbial? | Clean |
| `read_annotate__sylph` | @sec-tool-sylph | Which known genomes are in the sample? | Clean |
| `read_annotate__metaphlan` | @sec-tool-metaphlan | Which organisms, from clade-specific genes? | Clean |
| `read_annotate__humann` | @sec-tool-humann | Which gene families and functions? | Clean |
| `read_annotate__phyloflash` | @sec-tool-phyloflash | Which small-subunit rRNA genes? | Clean |
| `read_annotate__diamond` | @sec-tool-diamond | Which proteins of a chosen database, such as CAZymes? | Clean |
| `read_annotate__nonpareil` | @sec-tool-nonpareil | How well did the sequencing cover the community? | Clean |
| `read_annotate__ncyc` | @sec-tool-ncyc | Which genes of the nitrogen cycle? Only in `read_annotate_extra` | Clean |

Why so many? No single profiler is right for all questions, and they fail in different ways. If three of them agree that a sample is dominated by Prevotella, you can believe it. If they disagree, you've learned something about the sample, or about the databases. For a large project, you would pick the ones you need and not run all of them. Each can be called on its own.

Note the different starting points: Kraken2 reads what fastp left, **before** host removal. So its report also shows you the host, which the others can't. The other tools read the clean reads.

## Fast storage for big databases

Before the rules, one mechanism needs explaining, since the rules of Kraken2 and DIAMOND are long because of it.

Kraken2 with the standard database has to read 140 GB from disk, and on a network file system this takes very long. So the rule first copies the database to a fast local place. It has three choices:

1. `/dev/shm`, memory used as a disk, if the database fits and `kraken2_shm` is `"True"`
2. The local NVMe disk, if the database fits there
3. The original place, without copying, but only as a last resort

The rule measures what is free with `df` and compares this with the size of the database:

```bash
if [ "$db_size" -lt "$shm_avail" ]; then
    db_dst="$db_shm"
elif [ "$db_size" -lt "$nvme_avail" ]; then
    db_dst="$db_nvme"
elif [ {resources.attempt} -eq {params.max_attempt} ]; then
    db_dst="$db_src"
else
    echo "database too large for available fast storage; aborting attempt {resources.attempt} to trigger escalation"
    exit 1
fi
```

The third case explains the escalation here. If the database fits nowhere, the attempt fails on purpose, and the next resource set may offer a bigger disk. Only the last attempt runs from the slow original place.

At the end the rule removes the copy in `/dev/shm`. If the job gets killed before that, the copy stays until the node cleans up. This can be a reason why a later job on the same node sees less space.

With `copy_dbs: "False"` nothing is copied, and the database is read in place.

## Kraken2

### `read_annotate__kraken2__assign`

This is the only rule of the module that handles all samples in one job. Kraken2 loads its database for each run, and with a database in memory it's much quicker to reuse that one copy for all samples than to copy it for each. This has a consequence: the job gets all samples, so it's long, and if it dies, all samples of this database run again.

After staging, it loops over the samples:

```bash
kraken2 \
    --db "$db_dst" \
    --threads {threads} \
    --gzip-compressed \
    --paired \
    --report "$report" \
    --memory-mapping \
    "$forward" "$reverse" \
    2> "$sample_log" \
    | pigz --processes {threads} > "$out_gz"
```

`--memory-mapping` makes Kraken2 read the database files directly instead of loading them into its own memory. This is why they should be on a fast place, and why this saves memory when the files are in `/dev/shm`.

Without the option `--output`, Kraken2 writes its per-read output to the standard output, which goes through a pipe into `pigz`. Its messages go to the standard error, and so to the log of the sample.

The wildcard is `{kraken_db}`, so this rule runs once per database in `features.yaml`.

| File in `results/read_annotate/kraken2/{kraken_db}/` | Content |
|------|---------|
| `{sample}.{library}.report` | The summary per taxon, which is what you normally read |
| `{sample}.{library}.out.gz` | One line per read |
| `{sample}.{library}.log` | What Kraken2 printed, with the share of classified reads |

`read_annotate__kraken2` asks for the reports of all samples and databases.

### `read_annotate__krona__visualize`

This rule turns each report into an interactive chart:

```bash
ktImportTaxonomy -t 5 -m 3 {input} -o {output} --tax {params.krona_db}
```

The options say which columns of the report to use: the taxon from column 5, and its reads from column 3. @sec-tool-krona explains why this matters, and that charts from versions before 0.4.69 are wrong.

`read_annotate__krona` asks for one HTML file per sample and database.

## SingleM

### `read_annotate__singlem__pipe`

This rule runs `singlem pipe` on one library and writes three tables: the marker gene sequences (`otu_table`), the same in a form that can be combined later (`archive.json`), and the species profile (`condense.tsv`).

The rule writes the free space of `$TMPDIR` into the log, as SingleM can need a lot of it, and an error of a full disk is easier to see that way.

A comment in the rule points out that SingleM's documentation recommends raw reads. The pipeline uses clean reads here so that all tools see the same data.

### `read_annotate__singlem__condense`

This rule combines the `archive.json` files of all samples into one profile, `singlem.tsv`.

### `read_annotate__singlem__microbial_fraction`

This rule estimates which share of a library comes from Bacteria and Archaea, by comparing the profile with the amount of sequence. This is often the first number you want for a host-associated sample.

### `read_annotate__singlem__aggregate_microbial_fraction`

This rule stacks these results into one table with `csvstack`. `read_annotate__singlem` is the target.

## sylph

### `read_annotate__sylph_profile`

This is one simple call per library. Unlike the others, it reports genomes rather than taxa, and it needs no mapping or marker gene step:

```bash
sylph profile {input.db} -1 {input.forwards} -2 {input.reverses} -t {threads} > {output}
```

`read_annotate__sylph` asks for one table per library. There's no step that combines them. Note that the name of the first rule breaks the usual naming pattern, without the double underscore before `profile`.

## MetaPhlAn

### `read_annotate__metaphlan__run`

```bash
metaphlan {input.forward_},{input.reverse_} \
          --bowtie2out {output.bt2_out} \
          --nproc {threads} \
          --input_type fastq \
          -o {output.mp_out} \
          --bowtie2db {input.data}
```

`--bowtie2out` keeps the intermediate mapping, so that MetaPhlAn could be rerun with other settings without mapping again.

### `read_annotate__metaphlan__condense`

This rule merges the profiles into one table with `merge_metaphlan_tables.py`. `read_annotate__metaphlan` is the target.

## HUMAnN

### `read_annotate__humann__run`

HUMAnN doesn't use the pairing of the reads, so the rule simply puts both files together first, and this is valid for gzip files. The profile of MetaPhlAn is an input, which tells HUMAnN which species to look at first, so this rule runs after MetaPhlAn:

```bash
cat {input.forward_} {input.reverse_} > {output.cat}
humann --input {output.cat} --output {params.out_folder} \
       --threads {threads} \
       --protein-database {input.prot_dbs} \
       --nucleotide-database {input.nt_dbs} \
       --output-basename {params.out_name} \
       --taxonomic-profile {input.mp_out} \
       {params.additional_options}
```

| Option | Default | Meaning |
|--------|---------|---------|
| `read_annotate: humann: additional_options` | `--remove-temp-output` | Removes HUMAnN's large intermediate files |

The rule prints a warning about `TMPDIR`: on large data sets this folder needs a lot of space.

### `read_annotate__humann__condense`

This rule concatenates the tables of the gene families into `humann_genefamilies.tsv`. Note that it's a plain `cat`, so the result holds one block per sample, each with its own header, and not a table with one column per sample. Use `humann_join_tables` if you need that. `read_annotate__humann` is the target.

## phyloFlash

### `read_annotate__phyloflash__run`

```bash
phyloFlash.pl -dbhome {input.phyloflash_dbs} \
              -lib {params.lib} -CPUs {threads} \
              -read1 {input.forward_} -read2 {input.reverse_} \
              -almosteverything
mkdir -p {params.outdir}
mv {params.lib}.* {params.outdir}
```

phyloFlash writes to the current folder, which here is the project folder, and so the rule moves the files afterwards. The library name uses an underscore instead of a dot, as in `ERR2019410_lib1`. `-almosteverything` switches on the optional analyses, except the one with EMIRGE.

### `read_annotate__phyloflash__condense`

This rule concatenates the logs of all libraries. `read_annotate__phyloflash` is the target.

## DIAMOND

### `read_annotate__diamond__assign`

This rule compares the reads with a protein database. It does its staging in nearly the same way as Kraken2, and then runs twice, once per read file:

```bash
diamond blastx -d "$DB_LOC" -q {input.forwards} -o {output.out_R1} -p {threads} --max-target-seqs {params.max_target_seqs}
diamond blastx -d "$DB_LOC" -q {input.reverses} -o {output.out_R2} -p {threads} --max-target-seqs {params.max_target_seqs}
```

The two files aren't linked: each read gets its own best hit, also when the two mates of a pair disagree.

| Option | Default | Meaning |
|--------|---------|---------|
| `read_annotate: diamond: max-target-seqs` | 1 | How many hits to keep per read |

The wildcard `{diamond_db}` is a name in `features.yaml`.

### `read_annotate__diamond__summarise`

This rule runs an R script that turns the hits into feature tables, `summary_a.tsv` and `summary_b.tsv`. The script is found by the name of the database, as `workflow/scripts/downstream_scripts/create_featuretable_diamond_{diamond_db}.R`. **So if you add your own database under another name, you also have to provide this script**, otherwise this rule fails. `read_annotate__diamond` is the target.

## Nonpareil

### `read_annotate__nonpareil__run`

Nonpareil only uses one read of each pair, and it needs an uncompressed file:

```bash
zcat {input.forward_} > "${{prefix}}_1.fq"
nonpareil -s "${{prefix}}_1.fq" -T kmer -b "$prefix" -f fastq -t {threads} -X {params.X}
rm -f "${{prefix}}_1.fq"
```

| Option | Default | Meaning |
|--------|---------|---------|
| `read_annotate: nonpareil: X` | 100 | How many reads to compare against the rest. Smaller is quicker, and the comment in `params.yaml` says that this value is for testing, with 1000 as the default. Raise it for a real analysis |

All four outputs are marked `touch()`. The reason is in the comment of the rule: on samples with little coverage Nonpareil may not converge, and it can then leave empty files. `touch()` makes sure that Snakemake still sees the files that it expects, as @sec-file-flags explains.

### `read_annotate__nonpareil__aggregate`

This rule runs `workflow/scripts/nonpareil_summary.R`, which reads all results and writes `nonpareil.tsv`, with one line per library. `read_annotate__nonpareil` is the target.

## nCycDB

These rules are only part of the target `read_annotate_extra`, not of `read_annotate` or `all`.

### `read_annotate__ncyc__prepare_input`

This rule writes the sample sheet that the Perl script expects, using `workflow/scripts/prepare_ncyc_inputs.sh`.

### `read_annotate__ncyc__run`

This rule runs `workflow/scripts/NCycProfiler.PL`, which comes with the pipeline, on all samples at once. It uses DIAMOND for the search, and writes one table, `ncyc_results.tsv`. `read_annotate__ncyc` is the target.

## The options in one place

All options of this module in `params.yaml` are listed above. Everything else, such as the choice of databases, is in `features.yaml`, and the fast storage is set in `config.yaml`.

## What to look at after a run

1. **Kraken2:** what share of the reads was classified at all? In rumen samples, a low value is normal, because many rumen microbes aren't in the standard database. It says more about the database than about your sample.
2. **SingleM microbial fraction:** does it fit with what you know about the sample?
3. **Nonpareil:** is the coverage high enough? If it's low, a deeper sequencing would find many more organisms, and few MAGs are to be expected.
4. **Compare the profilers:** do they agree on the dominant groups?

## Summary

- The tools work on the reads, and each answers another question. You can run each on its own.
- Kraken2 uses the reads after fastp. The others use the clean reads.
- Kraken2 and DIAMOND copy their database to fast storage, and fail on purpose if it doesn't fit, so that a bigger resource set can take over.
- A new DIAMOND database needs a matching R script.
- nCycDB is only part of `read_annotate_extra`.
