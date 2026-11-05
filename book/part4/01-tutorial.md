# Tutorial with real data {#sec-tutorial}

This part runs the pipeline on real data, and it shows what comes out and how to read it. You can follow it on your own cluster, using the scripts in `tests/real_run/`.

::: {.callout-note}
## Where the output in this part comes from
All the output here is real. It comes from the pipeline's own rules, with the real tools in their containers, on **1 million read pairs per sample**. That's about a sixtieth of the data, on a computer with only Docker and 8 GB of memory. It's enough to see every file and to read every table, but the biology is thin, as you'll see. The numbers of MaxBin2, Nonpareil and all that follows from the genome catalogue come from before version 0.4.74, whose fixes change them. This part will get them from a new run.

The tools that need large databases couldn't run there, and neither could metaSPAdes. @sec-tutorial-waiting lists them, and those sections will be added from a complete run on a cluster. FastQC, Kraken2 and Krona ran by hand on a part of the reads, and the text says so where it applies.
:::

## The data

We use three public cow rumen metagenomes of the Ruminomics project (ENA study `PRJEB21508`):

| Run | Sample name | Read pairs | Bases |
|-----|-------------|-----------|-------|
| `ERR2019410` | UK54 | 60,740,071 | 12.3 Gb |
| `ERR2019412` | UK7 | 69,876,338 | 14.1 Gb |
| `ERR2019415` | UK8 | 77,030,215 | 15.6 Gb |

They were sequenced with an Illumina HiSeq 2000, with 2 x 101 bases. The prepared archive at <https://a3s.fi/Holoruminant-data/2025.11.25.reads.tar.gz> holds the full files, and also subsets with the first 10 million pairs of each file. Remember that these are the first reads of the file, not a random sample.

Rumen samples are a good example, and a hard one. The community is very diverse, and many of its members aren't in the databases. So you'll see lots of unclassified reads, and a modest assembly. That's what real data look like.

## Running it yourself

### On a cluster

These are the steps. `tests/real_run/README.md` has all the details, and @sec-setup explains the settings.

```bash
git clone https://github.com/fischuu/Snakebite-Holoruminant-MetaG.git
cd Snakebite-Holoruminant-MetaG
PIPELINE=$(pwd)

bash tests/real_run/setup_project.sh \
    --project /scratch/project_2009831/Snakebite_real_run \
    --account project_2009831 \
    --resources /scratch/project_2009831/RESOURCES/resources

cd /scratch/project_2009831/Snakebite_real_run
for stage in reads reference preprocess read_annotate assemble quantify contig_annotate mag_annotate eukaryote read_annotate_extra contig_annotate_extra; do
    bash $PIPELINE/tests/real_run/run_stage.sh "$stage" || break
done
```

### With only Docker

`book/examples/real_tools/` holds the scripts for the small run of this chapter. A stand-in for Apptainer starts the commands with Docker, as its `README.md` explains. Compared with a real project, this run differs in these ways:

| What | Here | In a real project |
|------|------|-------------------|
| Reads | 1 million pairs per sample | All of them, or the 10-million-pair subsets |
| Host genome | PhiX, a small phage genome | The genomes of your host |
| Assembler | MEGAHIT, as metaSPAdes needs more memory | metaSPAdes by default |
| Jobs | One at a time, without SLURM | On SLURM, in parallel |
| Images | Simple steps share an image, and QUAST and nCycDB ran in another image with the same tool | As in `.docker.yml` |
| MAGScoT threshold, dRep filter | Changed, as the section on dRep below explains | The defaults |

The tools ran under emulation, so ignore the run times, which are several times longer than they'd be on a normal x86 computer.

### The samples

```text
$ cat config/samples.tsv | cut -f 1,2,3,7
sample_id	library_id	forward_filename	assembly_ids
ERR2019410	lib1	reads/ERR2019410_1.fastq.gz	ERR2019410, coasm
ERR2019412	lib1	reads/ERR2019412_1.fastq.gz	coasm
ERR2019415	lib1	reads/ERR2019415_1.fastq.gz	coasm
```

So there are two assemblies: `ERR2019410`, from one sample, and `coasm`, a co-assembly of all three. Comparing them shows what a co-assembly brings.

## Stage `reads` {#sec-tutorial-reads}

@sec-module-reads explains this stage. Here's the first read:

```text
$ gzip -dc reads/ERR2019410_1.fastq.gz | head -n 4
@ERR2019410.1 HWI-1KL157:190:C7RW0ACXX:3:1101:1438:1968/1
NTTTTGCTTAAATGCCTTTTTTGTATGATATGTTTTACTCATTGTTTTATTTCAGTATTGTAATAATTGGGGTTTAGGTAATCTACTACTTTTTCTTAAAC
+
#0<FFFFFFFFFFIIIIIIIIIIFIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIFFIIFIIIIIIFIIIIBFFFFFBFFFFFFFFFFFFFFFFFFBFBB
```

The name tells you the flow cell and the position on it. The first base couldn't be called, so it's `N` with the lowest quality, `#`. The `I` stands for a quality of Q40.

The stage links the reads under fixed names, one per mate:

```text
$ ls results/reads | head -n 2
ERR2019410.lib1.log
ERR2019410.lib1_1.fq.gz
```

### FastQC

FastQC is part of this stage too. Under emulation it's very slow on all the reads, so this report comes from running the same version by hand on the first 100,000 reads of `ERR2019410`. @sec-tool-fastqc explains the checks.

```text
$ unzip -p demos/raw_fastqc.zip raw_fastqc/summary.txt | cut -f 1,2
PASS	Basic Statistics
PASS	Per base sequence quality
PASS	Per tile sequence quality
PASS	Per sequence quality scores
PASS	Per base sequence content
FAIL	Per sequence GC content
PASS	Per base N content
PASS	Sequence Length Distribution
PASS	Sequence Duplication Levels
WARN	Overrepresented sequences
PASS	Adapter Content
```

Don't let the `FAIL` alarm you. FastQC compares the GC content with a normal distribution, which fits a single genome, and a community of many organisms doesn't have to follow it. This is exactly the kind of `FAIL` that is normal in a metagenome.

The `WARN` deserves a look, and FastQC says what it found:

```text
$ unzip -p demos/raw_fastqc.zip raw_fastqc/fastqc_data.txt | sed -n '/^>>Overrepresented/,/^>>END_MODULE/p'
>>Overrepresented sequences	warn
#Sequence	Count	Percentage	Possible Source
GATCGGAAGAGCACACGTCTGAACTCCAGTCACGTGAAACGATCTCGTAT	340	0.33999999999999997	TruSeq Adapter, Index 19 (97% over 40bp)
>>END_MODULE
```

0.34% of the reads are nothing but adapter. They are fragments with no real insert, and fastp should remove them, as we'll check below. Note that this sequence starts like the adapter given in `samples.tsv`.

The basic statistics confirm what the name of the run promises:

```text
$ unzip -p demos/raw_fastqc.zip raw_fastqc/fastqc_data.txt | sed -n '/^>>Basic Statistics/,/^>>END_MODULE/p' | cut -f 1,2
>>Basic Statistics	pass
#Measure	Value
Filename	raw.fq.gz
File type	Conventional base calls
Encoding	Sanger / Illumina 1.9
Total Sequences	100000
Total Bases	10.1 Mbp
Sequences flagged as poor quality	0
Sequence length	101
%GC	44
>>END_MODULE
```

## Stage `reference` {#sec-tutorial-reference}

@sec-module-reference explains this stage. It recompresses each host genome. The generic rules then make the index files `.fai` and `.gzi`:

```text
$ ls results/reference/hosts
benchmark
phix.fa.gz
phix.fa.gz.fai
phix.fa.gz.gzi
phix.fa.gz.log
phix.log
```

## Stage `preprocess` {#sec-tutorial-preprocess}

@sec-module-preprocess explains this stage.

### What fastp did

fastp writes its report to the log, and the same numbers are in the JSON file. The first part shows the quality before:

```text
$ sed -n '/^Read1 before filtering/,/^$/p' results/preprocess/fastp/ERR2019410.lib1.log
Read1 before filtering:
total reads: 1000000
total bases: 101000000
Q20 bases: 100008538(99.0184%)
Q30 bases: 98147857(97.1761%)
```

And after:

```text
$ sed -n '/^Read1 after filtering/,/^$/p' results/preprocess/fastp/ERR2019410.lib1.log
Read1 after filtering:
total reads: 935567
total bases: 94418098
Q20 bases: 93982480(99.5386%)
Q30 bases: 92470684(97.9375%)
```

The share of good bases went up, and the reads with poor quality are gone. Why they went is in the next part:

```text
$ sed -n '/^Filtering result/,/^Insert size/p' results/preprocess/fastp/ERR2019410.lib1.log
Filtering result:
reads passed filter: 1871134
reads failed due to low quality: 125202
reads failed due to too many N: 2908
reads failed due to too short: 756
reads with adapter trimmed: 8757
bases trimmed due to adapters: 204920
reads with polyX in 3' end: 17840
bases trimmed in polyX tail: 387161

Duplication rate: 0.0513%

Insert size peak (evaluated by paired-end reads): 169
```

Here's how to read this:

- **93.6% of the reads passed.** Nearly all the rest failed on quality. That's a healthy result.
- **Few adapters.** 8,757 of 2 million reads had any, which fits the insert size of 169 bases: most fragments are longer than the reads.
- **Few duplicates.** 0.05%, which is what you expect in a very diverse community.

The other two samples look alike:

```text
$ grep -E '^reads passed filter|^reads failed due to low' results/preprocess/fastp/ERR2019412.lib1.log
reads passed filter: 1900732
reads failed due to low quality: 96792
```

```text
$ grep -E '^reads passed filter|^reads failed due to low' results/preprocess/fastp/ERR2019415.lib1.log
reads passed filter: 1910824
reads failed due to low quality: 83680
```

### FastQC after trimming

The same 100,000 reads after fastp look like this:

```text
$ unzip -p demos/trimmed_fastqc.zip trimmed_fastqc/summary.txt | cut -f 1,2
PASS	Basic Statistics
PASS	Per base sequence quality
PASS	Per tile sequence quality
PASS	Per sequence quality scores
PASS	Per base sequence content
WARN	Per sequence GC content
PASS	Per base N content
WARN	Sequence Length Distribution
PASS	Sequence Duplication Levels
PASS	Overrepresented sequences
PASS	Adapter Content
```

Compare the two reports. The warning about overrepresented sequences is gone, so fastp removed those adapters. The length distribution now has a warning, and this is expected: trimming makes reads shorter by different amounts, so they no longer all have the same length. This is why you have to read these marks and not simply count them.

### What host removal did

Bowtie2's summary is at the start of the log of each mapping:

```text
$ cat results/preprocess/bowtie2/phix/ERR2019410.lib1.log | grep -v bam_sort
935567 reads; of these:
  935567 (100.00%) were paired; of these:
    933569 (99.79%) aligned concordantly 0 times
    1998 (0.21%) aligned concordantly exactly 1 time
    0 (0.00%) aligned concordantly >1 times
    ----
    933569 pairs aligned concordantly 0 times; of these:
      70 (0.01%) aligned discordantly 1 time
    ----
    933499 pairs aligned 0 times concordantly or discordantly; of these:
      1866998 mates make up the pairs; of these:
        1866947 (100.00%) aligned 0 times
        51 (0.00%) aligned exactly 1 time
        0 (0.00%) aligned >1 times
0.22% overall alignment rate
```

Read it from the top. 1,998 pairs mapped as expected, 70 pairs mapped in an odd way, and from the rest, 51 single mates mapped. In the other two samples, the rate was 0.20% and 0.10%. PhiX is added to Illumina runs as a control, so these are likely real PhiX reads. In a real project this is where you would see how much cow DNA there is, and that can be a large share.

`flagstats` gives the same as a short list:

```text
$ cat results/preprocess/bowtie2/phix/ERR2019410.lib1.flagstats.txt | head -n 8
1871134 + 0 in total (QC-passed reads + QC-failed reads)
1871134 + 0 primary
0 + 0 secondary
0 + 0 supplementary
0 + 0 duplicates
0 + 0 primary duplicates
4187 + 0 mapped (0.22% : N/A)
4187 + 0 primary mapped (0.22% : N/A)
```

And the counts per sequence of the host, here with a single sequence, and with `*` for unplaced reads:

```text
$ cat results/preprocess/quantification/phix/ERR2019410.lib1.chr_alignment_counts.tsv
ENA|J02482|J02482.1 4187
* 0
```

### The clean reads

These are the files that everything else reads:

```text
$ ls results/preprocess/bowtie2/decontaminated_reads | grep -v -E 'log|benchmark'
ERR2019410.lib1_1.fq.gz
ERR2019410.lib1_2.fq.gz
ERR2019412.lib1_1.fq.gz
ERR2019412.lib1_2.fq.gz
ERR2019415.lib1_1.fq.gz
ERR2019415.lib1_2.fq.gz
```

Check that they're complete. This is the check that this very run made necessary, as @sec-tutorial-found tells:

```text
$ gzip -t results/preprocess/bowtie2/decontaminated_reads/*.gz && echo all complete
all complete
```

The number of lines, divided by 4, is the number of pairs:

```text
$ gzip -dc results/preprocess/bowtie2/decontaminated_reads/ERR2019410.lib1_1.fq.gz | wc -l
 3733792
```

That's 933,448 pairs. Before host removal there were 935,567, so 2,119 pairs were removed. That's more than the 1,998 proper pairs, because a pair with only one mapped mate is removed too.

Note that the names got shorter on the way, as `samtools fastq` keeps only the name and adds `/1`:

```text
$ gzip -dc results/preprocess/bowtie2/decontaminated_reads/ERR2019410.lib1_1.fq.gz | head -n 1
@ERR2019410.1/1
```

## Stage `read_annotate` {#sec-tutorial-read-annotate}

@sec-module-read-annotate explains this stage. Most of it needs large databases. Here we look at two tools that need little, and at Kraken2 with a toy database.

### Nonpareil

```text
$ cat results/read_annotate/nonpareil/nonpareil.tsv
sample_id	kappa	C	LR	modelR	LRstar	diversity
ERR2019410.lib1	0.13006	0.15496064380054214	94204505.60799976	0.9991269048010931	17344018571.196674	20.112522154756906
ERR2019412.lib1	0.04249	0.05573011944627605	95719612.90200004	NA	NA	0
ERR2019415.lib1	0.07556	0.09432453034231177	96251992.69799998	NA	NA	0
```

This is a useful table, and it says a lot:

- **`C` is the coverage.** With 1 million pairs, we've seen about 16%, 6% and 9% of the community. So most of what's there hasn't been sequenced at all, and this explains everything that follows.
- **`LR` is the amount of sequence used**, about 95 Mb.
- **`LRstar` is the sequence you'd need for 95% coverage**: 17 Gb in the first sample. The full file has 12.3 Gb, so even all of it wouldn't quite reach this. Treat this as a rough figure, as it's based on very little data and on a small `-X`.
- **`NA` and a diversity of 0** mean that the coverage of the other two samples is too low for a model. It doesn't mean that they have no diversity.

Also note that the two samples differ: the same amount of sequencing covers `ERR2019410` much better, so it's less diverse or it has more dominant organisms. We'll see this again below.

### nCycDB

This one needs only a small database. It's in `read_annotate_extra`.

```text
$ cut -f 1-4 results/read_annotate/ncyc/ncyc_results.tsv | head -n 6
#random sampling: 933448
Gene	ERR2019410.lib1_1	ERR2019410.lib1_2	ERR2019415.lib1_1
ansB	28	29	16
asnB	297	292	267
gdh_K00260	1	2	0
gdh_K00261	25	24	20
```

There's one row per gene family and one column per read file, not per library. All files were sampled to the same depth, as the first line says, so that the columns can be compared. `asnB` is an asparagine synthetase, which turns up in many organisms, so it's no surprise that it's the most frequent here.

### Kraken2 and Krona, on a toy database

The database of Kraken2 needs about 140 GB of memory, but its output formats can be shown with a toy database that holds only the genome of PhiX. This ran by hand on the first 100,000 read pairs after fastp, with the options of the rule. **The percentages here say nothing about the sample**, as only one genome is in the database.

Kraken2 prints this to its log:

```text
$ cat demos/sample.log
Loading database information... done.
100000 sequences (20.18 Mbp) processed in 3.168s (1894.0 Kseq/m, 382.26 Mbp/m).
  228 sequences classified (0.23%)
  99772 sequences unclassified (99.77%)
```

The report has a line per taxon, with the columns that @sec-tool-kraken2 lists:

```text
$ cat demos/sample.report
 99.77	99772	99772	U	0	unclassified
  0.23	228	0	R	1	root
  0.23	228	0	D	10239	  Viruses
  0.23	228	228	S	10847	    Escherichia virus phiX174
```

Note the difference between columns 2 and 3. All 228 pairs are in the clade of `root`, but only the species has them directly.

The per-read output has one line per pair, and it's complete, as the fixed rule writes it through a plain pipe:

```text
$ gzip -t demos/sample.out.gz && echo complete
complete
```

```text
$ gzip -dc demos/sample.out.gz | grep -m 2 '^C'
C	ERR2019410.1393	10847	101|101	10847:67 |:| 10847:67
C	ERR2019410.2997	10847	101|101	10847:67 |:| 10847:67
```

This says: classified, the name of the read, taxon 10847, two mates of 101 bases each, and for each mate, 67 k-mers that hit this taxon. A read of 101 bases has 67 k-mers of 35 bases, so here every k-mer agrees. And an unclassified one:

```text
$ gzip -dc demos/sample.out.gz | head -n 1
U	ERR2019410.1	0	101|101	0:67 |:| 0:67
```

Krona then draws the report, with the options of the rule. These are the levels in the chart:

```text
$ grep -oE '<node name="[^"]+"' demos/chart.html
<node name="Root"
<node name="No hits"
<node name="Viruses"
<node name="Monodnaviria"
<node name="Sangervirae"
<node name="Phixviricota"
<node name="Malgrandaviricetes"
<node name="Petitvirales"
<node name="Microviridae"
<node name="Bullavirinae"
<node name="Sinsheimervirus"
<node name="Sinsheimervirus phiX174"
```

It finds the lineage in its own taxonomy, from nothing but the taxon number, and it gives the species its 228 pairs:

```text
$ grep -A 6 'phiX174">' demos/chart.html | grep -oE '<magnitude><val>[0-9]+' | head -n 1
<magnitude><val>228
```

## Stage `assemble` {#sec-tutorial-assemble}

@sec-module-assemble explains this stage, step by step.

### Assembly

MEGAHIT goes through the k-mer sizes in its list. Note that it goes all the way up to 141 with reads of 101 bases:

```text
$ grep -h 'k list' results/assemble/megahit/coasm.log | cut -d ' ' -f 4-
k list: 21,31,41,51,61,71,81,91,101,111,121,131,141 
```

The summaries of the two assemblies:

```text
$ grep -h 'contigs, total' results/assemble/megahit/ERR2019410.log | cut -d ' ' -f 4-
549 contigs, total 1370369 bp, min 1500 bp, max 9706 bp, avg 2496 bp, N50 2415 bp
```

```text
$ grep -h 'contigs, total' results/assemble/megahit/coasm.log | cut -d ' ' -f 4-
900 contigs, total 2480429 bp, min 1500 bp, max 24283 bp, avg 2756 bp, N50 2858 bp
```

These are tiny assemblies, as you'd expect from a coverage of 5 to 16%. Only organisms that are abundant enough get contigs of at least 1500 bases. The co-assembly has more data, so it has more contigs, and the longest is much longer. On the full data, you can expect orders of magnitude more.

The contigs already have their pipeline names:

```text
$ gzip -dc results/assemble/megahit/coasm.fa.gz | head -n 1
>coasm:bin_NA@contig_00000001
```

### Mapping back

How many reads of each sample are in the co-assembly?

```text
$ grep 'overall alignment' results/assemble/bowtie2/coasm.ERR2019410.lib1.log
6.51% overall alignment rate
```

```text
$ grep 'overall alignment' results/assemble/bowtie2/coasm.ERR2019412.lib1.log
2.31% overall alignment rate
```

```text
$ grep 'overall alignment' results/assemble/bowtie2/coasm.ERR2019415.lib1.log
1.34% overall alignment rate
```

So more than 90% of the reads don't end up in the assembly. Again, this fits the coverage from Nonpareil. It's also the first sign that the assembled organisms are more abundant in `ERR2019410`.

These logs also hold many lines like the following. They're harmless: this rule writes CRAM without giving a reference, so `samtools` stores the sequences in the file itself.

```text
$ grep -m 1 'Failed to build reference' results/assemble/bowtie2/coasm.ERR2019410.lib1.log
[W::cram_encode_container] Failed to build reference, switching to non-ref mode
```

### Binning

MetaBAT2 reports what it did at the end of its log:

```text
$ tail -n 3 results/assemble/metabat2/ERR2019410.log
[00:00:02] 61.78% (846568 bases) of large (>=1500) and 0.00% (0 bases) of small (<1500) contigs were binned.
2 bins (846568 bases in total) formed.
[00:00:02] Finished
```

```text
$ tail -n 3 results/assemble/metabat2/coasm.log
[00:00:04] 50.61% (1254393 bases) of large (>=1500) and 0.00% (0 bases) of small (<1500) contigs were binned.
1 bins (1254393 bases in total) formed.
[00:00:04] Finished
```

For the co-assembly, the other binners give these:

```text
$ ls results/assemble/maxbin2/coasm results/assemble/metabat2/coasm
results/assemble/maxbin2/coasm:
maxbin2.001.fa.gz
maxbin2.002.fa.gz

results/assemble/metabat2/coasm:
bin.1.fa.gz
```

```text
$ ls results/assemble/concoct/coasm | wc -l
      21
```

Notice how differently the binners behave on the same contigs: MetaBAT2 makes one bin, MaxBin2 two, and CONCOCT twenty-one. That's why a refinement step follows.

### MAGScoT

MAGScoT needs the proteins, the marker genes and the bins:

```text
$ wc -l results/assemble/magscot/coasm/prodigal.faa results/assemble/magscot/coasm/hmm.tblout results/assemble/magscot/coasm/contigs_to_bin.tsv | head -n 3
   16099 results/assemble/magscot/coasm/prodigal.faa
      84 results/assemble/magscot/coasm/hmm.tblout
    2161 results/assemble/magscot/coasm/contigs_to_bin.tsv
```

There are 84 marker gene hits, in the format of protein, marker and E-value:

```text
$ head -n 3 results/assemble/magscot/coasm/hmm.tblout
coasm:bin_NA@contig_00000809_1	TIGR00029	2.7e-11
coasm:bin_NA@contig_00000758_1	TIGR00054	1.6e-63
coasm:bin_NA@contig_00000218_3	TIGR00059	1.6e-40
```

And here's the list of bins, with bin, contig and binner:

```text
$ head -n 2 results/assemble/magscot/coasm/contigs_to_bin.tsv
bin_20.fa.gz	coasm:bin_NA@contig_00000002	concoct
bin_3.fa.gz	coasm:bin_NA@contig_00000003	concoct
```

The scores of all the candidate bins are the most instructive table of this step:

```text
$ cut -f 1,2,3,4,7,8,10,13,14 results/assemble/magscot/coasm/magscot.scores.out
bin	set	uniqueSCGs	multipleSCGs	n_contigs	Completeness	Contamination	score	bintool
bin_11.fa.gz	gtdb_rel207_bac120	69	2	554	0.575	0.028985507246376812	0.5605072463768116	concoct
MAGScoT_1_1	gtdb_rel207_bac120	69	2	565	0.575	0.028985507246376812	0.5605072463768116	MAGScoT_1
MAGScoT_1_2	gtdb_rel207_bac120	69	2	612	0.575	0.028985507246376812	0.5605072463768116	MAGScoT_1
MAGScoT_1_3	gtdb_rel207_bac120	68	2	536	0.5666666666666667	0.029411764705882353	0.5519607843137255	MAGScoT_1
bin_bin.1.fa.gz	gtdb_rel207_bac120	67	2	409	0.5583333333333333	0.029850746268656716	0.543407960199005	metabat2
bin_maxbin2.001.fa.gz	gtdb_rel207_bac120	52	1	483	0.43333333333333335	0.019230769230769232	0.4237179487179487	maxbin2
bin_3.fa.gz	gtdb_rel207_ar53	1	0	171	0.018867924528301886	0	0.018867924528301886	concoct
bin_5.fa.gz	gtdb_rel207_bac120	1	0	7	0.008333333333333333	0	0.008333333333333333	concoct
bin_maxbin2.002.fa.gz	gtdb_rel207_bac120	20	6	369	0.16666666666666666	0.3	0.008333333333333331	maxbin2
```

Here's how to read the first line. Of the 120 bacterial marker genes, 69 occur once and 2 occur more than once, so the bin is 57.5% complete. The score is the completeness minus half the contamination: 0.575 − 0.5 × 0.029 = 0.5605.

You can see the logic at work here. All three binners found versions of the same organism, and the candidates in the upper lines share most of their markers. The `MAGScoT_1_` lines are the merged candidates that MAGScoT made itself. In this case, merging adds contigs but no new markers, so they don't beat the CONCOCT bin, which comes first. MaxBin2's second bin shows the opposite: it has 30% contamination, and this pulls its score down to almost nothing.

So one bin stands out, and it holds 554 of the 900 contigs. With the default threshold of 0.5, this is the result:

```text
$ cut -f 1,2,3,4,7,8,10,13,14 results/assemble/magscot/coasm/magscot.refined.out
bin	set	uniqueSCGs	multipleSCGs	n_contigs	Completeness	Contamination	score	bintool
bin_11.fa.gz	gtdb_rel207_bac120	69	2	554	0.575	0.028985507246376812	0.5605072463768116	concoct
```

```text
results/assemble/magscot/coasm/magscot.log:Refinement lead to a total of 1  bins with a score >= 0.5 
```

The assembly of the single sample doesn't reach the threshold with any bin.

The contigs now carry their bin in the name:

```text
$ gzip -dc results/assemble/magscot/coasm.fa.gz | head -n 1
>coasm:bin_000001@contig_00000001
```

### dRep, and two things that went wrong

Here the small data ran into two limits, and both are instructive.

The first attempt failed with this in its log:

```text
Running checkM
!!! checkM failed !!!
See https://drep.readthedocs.io/en/latest/advanced_use.html#troubleshooting-checkm for help troubleshooting
dRep wrote no genomes. Its messages are above, and results/assemble/drep/log/logger.log has the details.
```

CheckM, which dRep uses for its quality filter, ran its step with `pplacer`, and that step needs far more than the 7 GB available here. It's no issue on a cluster, as `assemble__drep__run` asks for 160 GB there. The last line of the message comes from the pipeline's rule. dRep itself reports success at this point, as @sec-tool-drep explains.

So we skipped the filter for this small run, by adding `--ignoreGenomeQuality` under `assemble: drep: extra` in `params.yaml`. Then dRep failed in another way:

```text
1 genomes were input to dRep
Running primary clustering
Running pair-wise MASH clustering
ValueError: The number of observations cannot be determined on an empty distance matrix.
```

With a single genome, it has nothing to compare. So, also for this small run only, we lowered `threshold` under `assemble: magscot` to 0.2, which also lets the single-sample assembly keep a bin:

```text
$ cut -f 1,2,3,4,7,8,10,13,14 results/assemble/magscot/ERR2019410/magscot.refined.out
bin	set	uniqueSCGs	multipleSCGs	n_contigs	Completeness	Contamination	score	bintool
bin_0.fa.gz	gtdb_rel207_bac120	51	2	450	0.425	0.0392156862745098	0.4053921568627451	concoct
```

**Don't do this in a real analysis without a good reason.** A genome that's 42% complete is a poor genome. Here we only want to see the following steps work.

Now dRep has two genomes, one from each assembly:

```text
$ ls results/assemble/drep/separated_bins results/assemble/drep/dereplicated_genomes | grep -v timestamp
results/assemble/drep/dereplicated_genomes:
coasm:bin_000001.fa.gz

results/assemble/drep/separated_bins:
ERR2019410:bin_000001.fa
coasm:bin_000001.fa
```

Two genomes went in, and one came out. They are the same species, and dRep kept the better one, the one from the co-assembly. That's exactly its job. The catalogue is this one genome:

```text
$ gzip -dc results/assemble/drep/dereplicated_genomes.fa.gz | grep -c '>'
554
```

```text
$ gzip -dc results/assemble/drep/dereplicated_genomes.fa.gz | grep -v '>' | tr -d '\n' | wc -c
 1647187
```

So 554 contigs and 1.65 Mb, from one organism that's abundant enough to be assembled from a few million reads.

## Stage `quantify` {#sec-tutorial-quantify}

@sec-module-quantify explains this stage. All reads go to the catalogue:

```text
$ grep 'overall alignment' results/quantify/bowtie2/ERR2019410.lib1.log
4.77% overall alignment rate
```

Now the tables. They have one row per genome, and one column per library:

```text
$ cat results/quantify/coverm/genome.count.tsv
sequence_id	ERR2019410.lib1	ERR2019412.lib1	ERR2019415.lib1
coasm:bin_000001	89007	23170	5028
```

The genome is about 18 times as abundant in the first sample as in the third. This is what we saw in the mapping rates, and it's what the coverage from Nonpareil hinted at. It's a real difference between these cows, or at least between these parts of the data.

```text
$ cat results/quantify/coverm/genome.covered_bases.tsv
sequence_id	ERR2019410.lib1	ERR2019412.lib1	ERR2019415.lib1
coasm:bin_000001	1630044	1035667	412130
```

```text
$ cat results/quantify/coverm/genome.length.tsv
sequence_id	ERR2019410.lib1	ERR2019412.lib1	ERR2019415.lib1
coasm:bin_000001	1647187	1647187	1647187
```

Dividing the two gives the share of the genome that's covered: 99%, 63% and 25%. That's the check that @sec-module-quantify recommends for whether a genome is really present. In all three samples, reads are spread over a good part of it, so it's there. The same 5,000 reads on one conserved gene would look quite different.

```text
$ cat results/quantify/coverm/genome.tpm.tsv
sequence_id	ERR2019410.lib1	ERR2019412.lib1	ERR2019415.lib1
coasm:bin_000001	1000000	1000000	1000000
```

Look at this table carefully, as it's a good warning. TPM says 1,000,000 in all three samples, while the counts differ by a factor of 18. The reason is that TPM is relative to what's mapped: with only one genome in the catalogue, it gets the whole share every time. **TPM can't tell you how much of a sample a genome is**, and only with many genomes does it say how they compare within a sample.

There's the same on the level of contigs:

```text
$ head -n 3 results/quantify/coverm/contig.count.tsv
sequence_id	ERR2019410.lib1	ERR2019412.lib1	ERR2019415.lib1
coasm:bin_000001@contig_00000001	78	10	2
coasm:bin_000001@contig_00000005	184	28	10
```

## Stage `contig_annotate` {#sec-tutorial-contig-annotate}

@sec-module-contig-annotate explains this stage. It looks at all contigs of the assemblies, not only those in bins.

### Genes

```text
$ grep -c '>' results/contig_annotate/prodigal/coasm/coasm.prodigal.fa
2828
```

That's 2,828 proteins on 2.5 Mb, or about one gene per 880 bases, which is what you expect from Bacteria. Here are the first two, whose headers have a lot of information:

```text
$ grep '>' results/contig_annotate/prodigal/coasm/coasm.prodigal.fa | head -n 2
>coasm:bin_NA@contig_00000001_1 # 3 # 2132 # 1 # ID=1_1;partial=11;start_type=Edge;rbs_motif=None;rbs_spacer=None;gc_cont=0.596
>coasm:bin_NA@contig_00000002_1 # 3 # 212 # -1 # ID=2_1;partial=10;start_type=ATG;rbs_motif=AGGTG;rbs_spacer=5bp;gc_cont=0.567
```

The first gene runs from base 3 to base 2132 of the first contig, on the forward strand. `partial=11` says that it's cut off at both ends, as it runs past both ends of the contig. That's very common with such short contigs.

### Counting reads per gene

```text
$ sed -n 2,4p results/contig_annotate/featurecounts/coasm/coasm_ERR2019410.lib1.prodigal_fc.txt
Geneid	Chr	Start	End	Strand	Length	results/assemble/bowtie2/coasm.ERR2019410.lib1.bam
1_1	coasm:bin_NA@contig_00000001	3	2132	+	2130	52
2_1	coasm:bin_NA@contig_00000002	3	212	-	210	35
```

The last column is the number of read pairs on that gene. Note that the gene names are `1_1`, and so on. They count the contigs in the file, so they are only unique within one assembly. The summary of how reads were assigned:

```text
$ grep -v -E '\s0$' results/contig_annotate/featurecounts/coasm/coasm_ERR2019410.lib1.prodigal_fc.txt.summary
Status	results/assemble/bowtie2/coasm.ERR2019410.lib1.bam
Assigned	54908
Unassigned_Unmapped	866638
Unassigned_NoFeatures	3772
Unassigned_Ambiguity	8130
```

Most fragments didn't map at all, as we know. Of those that mapped, most fell on a gene (54,908), and a few fell between genes or on two at once. This is typical of Bacteria, where genes cover most of the genome.

### Hydrogenases

HMMER looks for three classes of hydrogenases. There are no hits for two of them, and two for the third:

```text
$ grep -v -c '^#' results/contig_annotate/hmmer/fefe/coasm.tblout.tsv
0
```

```text
$ grep -v '^#' results/contig_annotate/hmmer/nife/coasm.tblout.tsv | awk '{print $1, $3, $5, $6}'
coasm:bin_NA@contig_00000421_2 NiFe 0.0068 12.4
coasm:bin_NA@contig_00000178_2 NiFe 0.056 9.4
```

But look at the scores in the last column: 12.4 and 9.4. The rule uses `--domT 34.5` for this profile, and it only applies to the table of domains, which has nothing:

```text
$ grep -v -c '^#' results/contig_annotate/hmmer/nife/coasm.domains-tblout.tsv
0
```

So these two weak hits don't pass the threshold. **Read the domain table for this rule**, not the `tblout` one, or apply the threshold yourself. With so few proteins, it's no surprise that there are no real hydrogenases here. You can expect them on the full data, as hydrogen metabolism is central in the rumen.

### CAMPER

Of all genes, a few have a hit to the polyphenol database:

```text
$ cut -f 1,3 results/contig_annotate/camper/coasm/annotations.tsv | awk -F '\t' 'NR > 1 && $2 != ""' | wc -l
       4
```

### nCycDB on contigs

As on the reads, but with one column per assembly:

```text
$ cut -f 1-3 results/contig_annotate/ncyc/ncyc_results.tsv | head -n 4
#random sampling: 1578
Gene	coasm.prodigal	ERR2019410.prodigal
asnB	0	0
gdh_K00262	0	1
```

## Stage `mag_annotate` {#sec-tutorial-mag-annotate}

@sec-module-mag-annotate explains this stage. Nearly all of it needs databases. Only QUAST could run here:

```text
$ cut -f 1,2 results/mag_annotate/quast/report.tsv | head -n 20
Assembly	dereplicated_genomes
# contigs (>= 0 bp)	554
# contigs (>= 1000 bp)	554
# contigs (>= 5000 bp)	56
# contigs (>= 10000 bp)	6
# contigs (>= 25000 bp)	0
# contigs (>= 50000 bp)	0
Total length (>= 0 bp)	1647187
Total length (>= 1000 bp)	1647187
Total length (>= 5000 bp)	401728
Total length (>= 10000 bp)	79168
Total length (>= 25000 bp)	0
Total length (>= 50000 bp)	0
# contigs	554
Largest contig	24283
Total length	1647187
GC (%)	56.88
N50	3208
N90	1726
auN	4161.0
```

An N50 of 3,208 bases says that the genome is in very small pieces. A good MAG from real sequencing depth has an N50 of tens of kilobases.

## Stage `eukaryote` {#sec-tutorial-eukaryote}

@sec-module-eukaryote explains this stage. Of its tools, Tiara could run here:

```text
$ cat results/eukaryote/tiara/log_coasm.tsv | head -n 7
First iteration statistics:
	archaea: 110
	bacteria: 723
	eukarya: 40
	prokarya: 22
	unknown: 5
```

So 40 of 900 contigs look eukaryotic. Rumen samples do contain protists and fungi, so that's plausible, but with contigs this short, don't lean on single labels. This is exactly the case for comparing with the other two tools of this module.

The table has one line per contig:

```text
$ cut -f 1,2,3 results/eukaryote/tiara/coasm.tsv | head -n 3
sequence_id	class_fst_stage	class_snd_stage
coasm:bin_NA@contig_00000001	bacteria	n/a
coasm:bin_NA@contig_00000002	bacteria	n/a
```

## The reports of this run {#sec-tutorial-reports}

The reports in `Rreports/` sum up all of the above, and @sec-module-report explains them. For this run, `tests/reports/run_test.sh` compares their tables with the numbers that this chapter took from the tools' own files. For example, the preprocess report has the 933,448 clean pairs of `ERR2019410`, and the assemble report has 900 contigs in the co-assembly with an N50 of 2,858.

Two things are different on a real cluster. Here, the reports can't show any memory use or CPU time, and they say so, because Snakemake's benchmark sees only Docker's client process when the containers run through the stand-in for Apptainer of this chapter. And the reports describe only what has run here: the sections of tools from @sec-tutorial-waiting say that they have no output.

## What this run found {#sec-tutorial-found}

Before these real runs, the rewritten pipeline had only been tested with stand-ins for its tools. Its first contact with the real ones found these problems, all of which are fixed now:

| What happened | Why stand-ins missed it |
|---------------|-------------------------|
| The clean reads were cut off, and MEGAHIT and Nonpareil failed on them with `unexpected end of file` | The stand-in tools finished at once, so nothing was still being written when the rule ended |
| `nonpareil.tsv` had no values at all when one library had too little coverage | Only the real R package returns this special form of table |
| dRep reported a failure of CheckM, but exited with 0 | A stand-in doesn't do this |

Reading the rules while writing this book found more, like the wrong columns for Krona. A dry run of each target found that `contig_annotate__featurecounts` couldn't start.

The lesson is general: **stand-ins test your plumbing, and only real tools test your assumptions about them.** @sec-testing returns to this. The numbers of this run are now stored as a test, as @sec-tests-in-repo describes.

## What's still waiting for the complete run {#sec-tutorial-waiting}

These parts need a large database, or more memory than this run had, so they have no real output on these data in this book yet. When the complete run on a cluster is done, its archive from `tests/real_run/collect.py` will fill them in. Their tool chapters in Part II describe the output formats.

| Stage | Tools | Why they couldn't run here |
|-------|-------|----------------------------|
| `reads`, `preprocess` | FastQC on all reads | Too slow under emulation. Shown here on 100,000 reads |
| `read_annotate` | Kraken2, Krona with a real database | About 140 GB of memory. Shown here with a toy database |
| `read_annotate` | SingleM, MetaPhlAn | Crash under emulation, and large databases |
| `read_annotate` | sylph, HUMAnN, phyloFlash, DIAMOND with CAZy | Databases |
| `assemble` | metaSPAdes | Memory |
| `contig_annotate` | eggNOG-mapper, eggNOG 7, DIAMOND with HydDB | Databases |
| `mag_annotate` | CheckM2, GTDB-Tk, PhyloPhlAn, DRAM, Bakta, eggNOG-mapper, Proteinortho, CAMPER | Databases |
| `eukaryote` | 4CAC | It needs the graph of metaSPAdes |
| `eukaryote` | REMAG | Too slow without a suitable processor |

Run times and memory on real hardware will come from that run too, from `sacct`.
