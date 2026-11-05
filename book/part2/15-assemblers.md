# Assembly: the idea {#sec-tool-assembly-idea}

Assembly is the step that turns short reads into long contigs. Both assemblers of the pipeline work on the same principle, so here's the idea, before looking at each of them.

## The de Bruijn graph

If you wanted to find overlaps directly, you would compare each read with every other. With hundreds of millions of reads, that's out of the question. Short-read assemblers do something smarter.

They cut all reads into k-mers. Then they build a graph in which each k-mer is a connection between two nodes, its first k−1 bases and its last k−1 bases. Overlapping k-mers end up on a path through this graph. If a stretch of the genome is unique, there's a single path, and you can walk along it and read off a contig.

The graph has to hold only the distinct k-mers and not all reads, so its size depends on how complex the community is, rather than on the amount of sequencing. That's why deep sequencing of a simple sample needs less memory than shallow sequencing of soil.

## The choice of k

The value of k is a trade-off:

- **A small k** connects reads even at low coverage. But short k-mers occur in many places by chance, so the graph gets tangled.
- **A large k** separates repeats and similar organisms well. But two reads must overlap by at least k bases, so regions of low coverage fall apart.

A community has abundant organisms and rare ones, so no single k fits. Both assemblers therefore run several times with growing k, and each round builds on the contigs of the round before. This is called iterative assembly. Small k-mers recover the rare organisms, and large ones resolve the abundant ones.

A read shorter than k can't add a k-mer of its own, so the largest useful k is usually close to the read length. Beyond that, a round can only build on the contigs of the round before.

## Why metagenomes are hard

Assemblers for a single genome expect even coverage, and they treat a sudden change in coverage as an error. In a metagenome, coverage differs by orders of magnitude between organisms, so low coverage can be real.

Worse, close relatives share long stretches of DNA. In the graph, these form bubbles and tangles. Assemblers break contigs at such points to avoid mixing organisms, and that's why metagenome assemblies are so fragmented, and why strain diversity usually lowers their quality.

## Which to choose

| | metaSPAdes | MEGAHIT |
|---|---|---|
| Quality | Usually longer contigs | Usually somewhat shorter |
| Memory | High, often several hundred GB for large data | Low, often an order of magnitude less |
| Time | Long | Short |
| Co-assembly of many samples | Often too heavy | Designed for it |
| Assembly graph available | Yes, needed by 4CAC | Not kept here |
| Several libraries | Only one, so they are pooled | Yes |

For a first look, or for very large co-assemblies, start with MEGAHIT. If metaSPAdes finishes on your data, its assemblies tend to give better bins. The setting `assembler` in `config.yaml` switches between them.

# MEGAHIT {#sec-tool-megahit}

## What it does

MEGAHIT assembles metagenomes, with very little memory for the size of data it can handle. It's the assembler of choice for very large or very complex data.

## How it works

It uses a succinct de Bruijn graph, a compressed form of the graph that takes only a few bits per k-mer. It runs iteratively, from `--k-min` to `--k-max` in steps of `--k-step`. At low k, it also adds so-called mercy k-mers, to rescue k-mers of low coverage that would otherwise break a contig.

## Input

FASTQ or FASTA. Paired reads go in with `-1` and `-2`, and several libraries are given as a list separated by commas.

## Output

| File | Content |
|------|---------|
| `final.contigs.fa` | The contigs. The names look like `k141_1234`, and the header holds the coverage and length |
| `intermediate_contigs/` | Results of each k |
| `log` | All steps. It also includes a summary with the number of contigs and the N50 |
| `options.json`, `done` | State, which allows resuming with `--continue` |

## When to use it

Use it for large co-assemblies, for soil and other very complex samples, and when memory is limited. Its presets are named for this: `meta-sensitive` for more sensitivity at the price of time, and `meta-large` for large and complex data, with `--k-min 27 --k-max 127 --k-step 10`.

## In this pipeline

The rule `assemble__megahit__run` runs it when `assembler` is `"megahit"`, as @sec-module-assemble shows. All the k-mer options come from `params.yaml`.

- The default of `--k-max 141` suits reads of 150 bases. MEGAHIT doesn't lower it for shorter reads: in a real run with reads of 101 bases, it went through all k-mer sizes up to 141. For such reads, a lower value in `params.yaml` can save time.
- `--min-contig-len 1500` removes short contigs right away. MEGAHIT's own default is 200, but the binners use contigs from about 1500 bases, so shorter ones would mostly be ballast here. If you want the short contigs too, for gene-based work, then lower this value. The comment in `params.yaml` says the same.
- `--force` is needed because the folder exists already, and `--continue` lets it resume.

## On real data

@sec-tutorial-assemble shows real output of this tool, and how to read it.

## Pitfalls

- **`--memory`.** By default, MEGAHIT may use 90% of the machine's memory. In a SLURM job, this means the node's memory, not the job's, and so it can go beyond the allocation and get killed. If this happens, give it a limit through `additional_options` in `params.yaml`.
- **Temporary disk space.** It needs a lot of space in the output folder while running.
- **`--no-mercy`.** Recommended for samples with deep coverage (over 30x), where the mercy k-mers only add noise to the graph.

## Reference

Li D, Liu CM, Luo R, Sadakane K, Lam TW (2015). MEGAHIT: an ultra-fast single-node solution for large and complex metagenomics assembly via succinct de Bruijn graph. *Bioinformatics*. <https://doi.org/10.1093/bioinformatics/btv033>

# metaSPAdes {#sec-tool-metaspades}

## What it does

metaSPAdes is the metagenome mode of the SPAdes assembler. It usually yields longer and more accurate contigs than MEGAHIT, and it needs much more memory and time.

## How it works

It starts by correcting read errors, using BayesHammer. It then builds de Bruijn graphs at several values of k, and it simplifies them with methods for uneven coverage. It uses the pairing of the reads to resolve repeats, and it tries to follow the dominant strain through the variation between close relatives, rather than breaking at each difference.

## Input

Paired reads with `-1` and `-2`. In this mode, it accepts exactly **one paired-end library**. So several libraries have to be pooled first. Single-end reads alone aren't supported in the metagenome mode.

## Output

| File | Content |
|------|---------|
| `contigs.fasta` | The contigs, named like `NODE_1_length_5000_cov_12.5` |
| `scaffolds.fasta` | Contigs joined with the help of read pairs |
| `assembly_graph_with_scaffolds.gfa` | The assembly graph |
| `contigs.paths`, `scaffolds.paths` | How the sequences run through the graph |
| `spades.log`, `params.txt` | The log and the settings |

The name of a contig tells you about its length and coverage, which is handy. A folder for each k holds the intermediate results, so that a working folder can hold a large number of files.

## When to use it

Use it for samples of moderate size, when you have the memory. It's a good default for single samples or small co-assemblies. For a very large co-assembly, it may not finish, so then go to MEGAHIT.

## In this pipeline

The rule `assemble__metaspades__run` runs it, as @sec-module-assemble shows, and it uses `contigs.fasta`, not the scaffolds. The working folder gets packed into an archive at the end, and 4CAC reads its graph from there.

Three settings are important:

- **`-k 21,33,55`.** This is the default in the metagenome mode for reads of this length. If you have reads of 150 bases, you could try larger values, such as `21,33,55,77`.
- **`--only-assembler`** skips the read correction, which saves much time and memory, at some cost in quality. This was chosen for this pipeline, and you can remove it in `params.yaml` if you can afford it.
- **`-m`.** metaSPAdes takes this in gigabytes, and it stops when it reaches that limit. The rule gives it `{resources.mem_mb}`, which is in megabytes, so the value is about a thousand times too high. In effect it's no limit, and it's the job's memory limit that counts. The job then gets killed by SLURM, instead of metaSPAdes stopping by itself.

`metaspades_slots` in `config.yaml` limits how many run at the same time.

## On real data

This book has no real output of this tool yet. @sec-tutorial-waiting says why, and it will come from a complete run on a cluster.

## Pitfalls

- **Running out of memory** is the most common failure. The log's last lines tell you how far it got. To give it more, add a larger resource set to the rule in `escalation.yaml`.
- **Restarting.** After a failure of the job, the working folder stays there. To use it, you could resume with `--continue`, but the rule doesn't do that.
- **Many small files.** These can be a real problem for shared file systems, and they are also a reason for packing them into an archive.

## Reference

Nurk S, Meleshko D, Korobeynikov A, Pevzner PA (2017). metaSPAdes: a new versatile metagenomic assembler. *Genome Research*. <https://doi.org/10.1101/gr.213959.116>
