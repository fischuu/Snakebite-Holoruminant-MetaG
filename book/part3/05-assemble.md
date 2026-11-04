# Module `assemble` {#sec-module-assemble}

This is the heart of the pipeline. It turns millions of short reads into a catalogue of genomes, known as metagenome-assembled genomes or MAGs. Everything in the modules `quantify` and `mag_annotate` builds on this catalogue.

```bash
bash run_Snakebite-Holoruminant-MetaG.sh assemble
```

## The idea

The reads of a metagenome come from thousands of organisms, all mixed. To get genomes out of this, four steps are needed.

1. **Assemble.** Overlapping reads are joined into longer pieces, the contigs. At this stage, you don't know which contig belongs to which organism.
2. **Bin.** Contigs of one organism look similar: they have a similar base composition, and a similar coverage in each sample, because the amount of an organism in a sample affects all its contigs alike. A binner uses this to sort contigs into groups, the bins.
3. **Refine.** Binners make different mistakes. The pipeline runs three of them, scores all their bins by marker genes, and builds the best set from all of them.
4. **Dereplicate.** The same species can come out of several assemblies. dRep keeps one genome per species, which gives the final catalogue.

## The flow

```
clean reads of the libraries of one assembly
        │  assemble__megahit__run or assemble__metaspades__run
        ▼
results/assemble/{assembler}/{assembly_id}.fa.gz                    the contigs
        │  assemble__bowtie2__build__run, assemble__bowtie2__map
        ▼
results/assemble/bowtie2/{assembly_id}.{sample_id}.{library_id}.cram
        │  assemble__concoct__run, assemble__maxbin2__run, assemble__metabat2__run
        ▼
results/assemble/{concoct,maxbin2,metabat2}/{assembly_id}/*.fa.gz   the bins of each binner
        │  the six MAGScoT rules, see below
        ▼
results/assemble/magscot/{assembly_id}.fa.gz                        the contigs in refined bins
        │  assemble__drep__split_bins, assemble__drep__run, assemble__drep__catalogue
        ▼
results/assemble/drep/dereplicated_genomes.fa.gz                    the MAG catalogue
```

Note that the last steps collect all assemblies: the wildcard `{assembly_id}` disappears at dRep, and there is one catalogue in the end, however many assemblies you have.

The final target only asks for the catalogue:

```python
rule assemble:
    input:
        MAG_CATALOGUE,
```

Snakemake works out the rest backwards, as @sec-chaining explains.

## Which reads go into which assembly

The column `assembly_ids` of `samples.tsv` decides this, as @sec-setup explains. Three helper functions in `workflow/rules/assemble/__functions__.smk` use it.

`libraries_of_assembly` lists the libraries of one assembly. `assembly_reads(end)` turns this into paths of one mate. These are the clean reads, or fastp's reads if no host is configured. `assembly_alignments` lists the mapping of each library against an assembly. This is how the binners find their input. Its companion `assembly_alignment_indexes` adds the index files.

Contigs and mappings are linked through the constant `CONTIGS`. It holds `results/assemble/<assembler>/{assembly_id}.fa.gz`, where `<assembler>` comes from the configuration. All later rules use this constant, and so they don't care which assembler made the contigs.

## Assembling

Only one of the two assemblers runs in a project, namely the one in `config.yaml`. @sec-tool-metaspades and @sec-tool-megahit compare them. In short, metaSPAdes tends to give better assemblies, and it needs much more memory. MEGAHIT is the economical choice, and it's a fall-back if metaSPAdes doesn't finish.

### `assemble__metaspades__run`

```bash
cat {input.forwards} > {output.pooled_forward}
cat {input.reverses} > {output.pooled_reverse}
metaspades.py -1 {output.pooled_forward} -2 {output.pooled_reverse} -o {params.workdir} \
    -t {threads} -m {resources.mem_mb} -k {params.settings[kmer_size]} \
    {params.settings[additional_options]}
python {params.script_folder}/contig_ids.py {wildcards.assembly_id} {params.workdir}/contigs.fasta \
    | bgzip -l 9 -@ {threads} > {output.contigs}
tar -cv -I "pigz -9 -p {threads}" --remove-files -f {output.workdir_archive} {params.workdir}
```

metaSPAdes takes only one library in this mode, so the rule pools the reads first, and it deletes the pooled files later, because they are `temp()`.

The working folder holds hundreds of thousands of small files, which is bad for a shared file system. So the rule packs it into one archive at the end, and it removes the original. The module `eukaryote` later reads the assembly graph from this archive.

| Option | Default | Meaning |
|--------|---------|---------|
| `assemble: metaspades: kmer_size` | `"21,33,55"` | The k-mer sizes to use. See @sec-tool-metaspades |
| `assemble: metaspades: additional_options` | `"--only-assembler"` | Skips the read error correction, which saves a lot of time and memory |

Be aware that `-m` gets the memory in megabytes, while metaSPAdes reads this number as gigabytes. So it doesn't act as a limit here, and the memory limit of the SLURM job is what counts.

The target `assemble__metaspades` asks for all assemblies. `metaspades_slots` in `config.yaml` limits how many of these jobs run at once.

### `assemble__megahit__run`

```bash
megahit -1 {params.forwards} -2 {params.reverses} -o {params.workdir} -t {threads} \
    --min-count {params.settings[mincount]} \
    --k-min {params.settings[kmin]} --k-max {params.settings[kmax]} --k-step {params.settings[kstep]} \
    --min-contig-len {params.settings[min_contig_len]} \
    --force --continue --verbose {params.settings[additional_options]}
```

MEGAHIT takes several libraries directly, separated by commas, which `assembly_reads(end, separator=",")` builds. `--force` is needed because Snakemake has already created the output folder, and MEGAHIT would otherwise refuse to write there.

| Option | Default | Meaning |
|--------|---------|---------|
| `assemble: megahit: mincount` | 2 | How often a k-mer must occur to count |
| `assemble: megahit: kmin` | 21 | Smallest k-mer. Use 27 for complex communities |
| `assemble: megahit: kmax` | 141 | Largest k-mer. MEGAHIT goes up to this value also with shorter reads. Use 127 for complex communities |
| `assemble: megahit: kstep` | 10 | Step between k-mer sizes |
| `assemble: megahit: min_contig_len` | 1500 | Shorter contigs aren't reported |
| `assemble: megahit: additional_options` | `""` | For example `--no-mercy` for samples with deep coverage |

The target `assemble__megahit` asks for all assemblies.

### The contig names

Both assemblers end with `workflow/scripts/contig_ids.py`, which renames the contigs like this:

```
ERR2019410:bin_NA@contig_00000001
```

This name carries information that later steps read: the assembly, the bin (`NA` until there is a bin), and a number. The `@` separates the genome from the contig, and CoverM uses that later on to add up the contigs of a genome. **Don't change this format**, as several scripts depend on it.

### Your own assemblies

With another value of `assembler`, such as `long_reads`, no assembler runs. Put your files into `results/assemble/long_reads/{assembly_id}.fa.gz`. Rename the contigs first with `workflow/scripts/rename_provided_assemblies.py`, because the format above is required.

## Mapping the reads back

Binners need to know the coverage of each contig in each library.

### `assemble__bowtie2__build__run`

This rule indexes the contigs of one assembly. As in the module `preprocess`, an empty file made by `touch()` stands in for the index. The target `assemble__bowtie2__build` asks for the index of all assemblies.

### `assemble__bowtie2__map`

```bash
bowtie2 --threads {threads} --rg-id '{params.rg_id}' --rg '{params.rg_extra}' \
        -x {input.index} -1 {input.forward_} -2 {input.reverse_} \
    | samtools view -b -o {output.unsorted} -
samtools sort -@ {threads} -m {params.sort_memory} -l 9 -O {SAMTOOLS_OUTTYPE} \
    -o {output.alignment} {output.unsorted}
```

Each library is mapped only to the assemblies it belongs to. So in a co-assembly, every sample of the group is mapped. If each sample has its own assembly, a sample is only mapped to its own assembly, and a binner then has one coverage value per contig. This is one reason why co-assemblies often give better bins.

| Option | Default | Meaning |
|--------|---------|---------|
| `assemble: samtools: mem` | `8G` | Memory for `samtools sort`, per thread. Make sure this multiplied by the threads fits into the job |
| `assemble: samtools: out_type` | `cram` | Change this to `bam` if the mapping rule fails with an error about the CRAM header. Very long contig names can cause this |

The target `assemble__bowtie2` asks for all mappings of all assemblies.

## Binning

All three binners get the contigs and the mappings, and all three produce a folder with one `.fa.gz` file per bin. @sec-tool-concoct, @sec-tool-maxbin2 and @sec-tool-metabat2 explain how they differ.

These rules declare a whole folder as output with `directory()`, because nobody can know beforehand how many bins there will be.

### `assemble__concoct__run`

The rule follows the steps of CONCOCT's manual:

1. `cut_up_fasta.py` cuts the contigs into pieces of 10 kb, so that long contigs get more weight.
2. `samtools view` makes a BAM file of the mapped reads, for each library, as the next step needs BAM.
3. `concoct_coverage_table.py` computes the coverage of the pieces.
4. `concoct` clusters the pieces.
5. `merge_cutup_clustering.py` goes back from pieces to contigs.
6. `extract_fasta_bins.py` writes the bins.

At the end only the bins remain. Note the expression `<(zcat {input.contigs})`, which hands the uncompressed contigs to a tool that wants a file name, without writing them to the disk.

The target is `assemble__concoct`. This rule is the only one of the three with its own container, `docker["concoct"]`.

### `assemble__maxbin2__run`

MaxBin2 only takes one abundance value per contig:

```bash
samtools coverage {input.alignments} | sed '/^#/d' | cut -f 1,5 > {output}/maxbin2.coverage
run_MaxBin.pl -contig {input.contigs} -abund {output}/maxbin2.coverage -out {output}/maxbin2 \
    -min_contig_length {params.min_contig} -thread {threads}
```

Note what the comment of the rule points out: column 5 of `samtools coverage` is the number of covered bases, and not the mean depth, which is column 7. So it's the amount of covered sequence that is used as the abundance. Also, with several libraries, `samtools coverage` adds them up into one value.

The rule then renames `.fasta` to `.fa`, compresses the bins, and removes the other files of MaxBin2. The target is `assemble__maxbin2`.

| Option | Default | Meaning |
|--------|---------|---------|
| `assemble: maxbin: min_contig_len` | 1500 | Ignore shorter contigs |

### `assemble__metabat2__run`

```bash
jgi_summarize_bam_contig_depths --outputDepth "$depth" --pairedContigs "$pairs" "${{bams[@]}}"
metabat2 -i {input.contigs} -a "$depth" -o {output}/bin \
    -m {params.min_contig} -t {threads} -v
```

MetaBAT2 uses one depth per contig and library, so it gains the most from having several samples in an assembly. The target is `assemble__metabat2`.

| Option | Default | Meaning |
|--------|---------|---------|
| `assemble: metabat: min_contig_len` | 1500 | Ignore shorter contigs. MetaBAT2 doesn't accept less than 1500 |

## Refining: MAGScoT

MAGScoT takes the bins of all binners, scores them by marker genes, and combines them. @sec-tool-magscot explains the method. Six rules prepare and run it. Everything of one assembly stays in `results/assemble/magscot/{assembly_id}/`.

### `assemble__magscot__prodigal`

Marker genes are proteins, so we need the proteins first:

```bash
zcat {input} \
    | parallel -j {threads} --block 1M --recstart '>' --pipe --keep-order \
        prodigal -p meta -a /dev/stdout -d /dev/null -o /dev/null \
    > {output}
```

Prodigal itself uses one thread. `parallel` splits the FASTA stream into blocks of 1 MB at the start of a record, and it hands each to its own Prodigal. `--keep-order` keeps the result in the original order. `-p meta` is Prodigal's mode for metagenomes.

The comment in the rule explains why it sets its own `TMPDIR`: GNU parallel keeps control files there, and the usual value points to a place that the container can't see.

### `assemble__magscot__hmmsearch`

```bash
hmmsearch -o /dev/null --tblout "${{hits%.gz}}" --noali --notextw --cut_nc --cpu {threads} \
    {input.hmm} {input.proteins}
```

This rule runs once per assembly and marker set. Its wildcard `{marker_set}` can only be `pfam` or `tigr`, as `wildcard_constraints` says, and these are the two profiles in `features.yaml`. `--cut_nc` uses the score threshold that comes with each profile.

### `assemble__magscot__marker_table`

This rule brings both results into the format MAGScoT wants: protein, marker and e-value. Note that TIGRFAM names the marker in column 3, and Pfam in column 4.

### `assemble__magscot__merge_contig_to_bin`

This rule lists which contig is in which bin of which binner. It reads all bins with `zcat`, and writes one line per contig: bin, contig, binner.

### `assemble__magscot__run`

```bash
Rscript --vanilla {params.script_folder}/MAGScoT/MAGScoT.R -i {input.contigs_to_bin} \
    --hmm {input.markers} -o {params.prefix} -t {params.settings[threshold]} \
    {params.settings[extra]} \
    || echo "MAGScoT failed, most likely no viable bins: continuing without bins"
touch {output}
```

Look at the `||`. A poor assembly can leave MAGScoT without a viable bin, and it reports this by failing. The rule treats this as a result and not as a problem, and it continues with empty tables, so that one bad assembly doesn't stop a whole project. **This also hides real failures of MAGScoT**, so if an assembly has no bins, read this log.

| Option | Default | Meaning |
|--------|---------|---------|
| `assemble: magscot: threshold` | `"0.5"` | Minimum completeness of a bin, as a fraction |
| `assemble: magscot: extra` | `"--n_iter=1"` | Further options. The comment in `params.yaml` says that this value could be a relict from testing, so check it for a real analysis |

MAGScoT's script comes with the pipeline, in `workflow/scripts/MAGScoT/`.

### `assemble__magscot__label_contigs`

This rule writes the refined bin into each contig name, and it keeps only the contigs in a bin:

```
ERR2019410:bin_NA@contig_00000001      before
ERR2019410:bin_00012@contig_00000001   after
```

Contigs without a bin are dropped here, and they don't go on to the catalogue. The target of the whole section is `assemble__magscot`.

## Dereplicating: dRep

### `assemble__drep__split_bins`

dRep wants one file per genome. This rule splits the contigs of all assemblies by their bin, with `workflow/scripts/split_bins.sh`. Since the assembly is part of the name, bins from different assemblies don't get mixed up.

### `assemble__drep__run`

```bash
rm -rf {DREP}/{{data,data_tables,dereplicated_genomes,figures,log}}
dRep dereplicate {DREP} -g {input}/*.fa -p {threads} \
    -comp {params.settings[completeness]} -con {params.settings[contamination]} \
    -pa {params.settings[P_ani]} -sa {params.settings[S_ani]} -nc {params.settings[nc]} \
    {params.settings[extra]}
```

The `rm` removes what a failed attempt may have left, because dRep won't start in such a folder. @sec-tool-drep explains the method.

After dRep, the rule checks that there are genomes, and it stops with a message if there aren't. This is needed because dRep can report that CheckM failed, and still exit with 0.

| Option | Default | Meaning |
|--------|---------|---------|
| `assemble: drep: completeness` | 50 | Minimum completeness of a genome, in percent |
| `assemble: drep: contamination` | 50 | Maximum contamination, in percent |
| `assemble: drep: P_ani` | 0.9 | Primary clustering threshold, using a fast estimate |
| `assemble: drep: S_ani` | 0.95 | Secondary clustering threshold. 95% ANI is the usual definition of a species |
| `assemble: drep: nc` | 0.1 | Minimum share of the genome that two genomes must have in common |
| `assemble: drep: extra` | `" "` | Further options |

With the default of `S_ani`, the catalogue holds about one genome per species. For strain-level questions, you would raise it to 0.99.

Note also the permissive limits for completeness and contamination: a genome with 50% contamination is a poor one. Look at the results of CheckM2 in @sec-module-mag-annotate before using a genome.

### `assemble__drep__catalogue`

This rule concatenates all genomes into one file, `dereplicated_genomes.fa.gz`, the MAG catalogue. The target is `assemble__drep`.

## What you get

| Path in `results/assemble/` | Content |
|------|---------|
| `{assembler}/{assembly_id}.fa.gz` | The contigs |
| `{assembler}/{assembly_id}.tar.gz` | The working folder of the assembler |
| `bowtie2/{assembly_id}.{sample}.{library}.cram` | The mapping |
| `concoct/`, `maxbin2/`, `metabat2/` | The bins of each binner |
| `magscot/{assembly_id}/magscot.refined.out` | The refined bins with their scores |
| `magscot/{assembly_id}.fa.gz` | The contigs in refined bins |
| `drep/dereplicated_genomes/` | One FASTA per genome |
| `drep/dereplicated_genomes.fa.gz` | The MAG catalogue |

## What to look at after a run

1. **Assembly:** how many contigs over 1500 bases, and how long are they? @sec-tool-quast explains the numbers.
2. **Mapping rate:** how many clean reads map back to their assembly? If only a small share does, much of the community isn't assembled.
3. **MAGScoT logs:** did every assembly give bins?
4. **dRep:** how many genomes came in, and how many are left?

## Summary

- Contigs are made by one assembler, and reads are mapped back to them.
- Three binners sort the contigs into bins, and MAGScoT makes the best set out of them.
- dRep reduces the bins of all assemblies to one catalogue, with about one genome per species.
- The contig names carry information, and they must keep their format.
- A failure of MAGScoT is treated as "no bins", so check its log if bins are missing.
