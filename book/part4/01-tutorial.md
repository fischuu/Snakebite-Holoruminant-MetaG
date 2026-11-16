# Tutorial with real data {#sec-tutorial}

This part runs the pipeline on real data, and it shows what comes out and how to read it. You can follow it on your own cluster, using the scripts in `tests/real_run/`.

::: {.callout-note}
## Where the output in this part comes from
All the output here is real. It comes from the pipeline's own rules, with the real tools in their containers, on **1 million read pairs per sample**. That's about a sixtieth of the data, on a computer with only Docker and 8 GB of memory. It's enough to see every file and to read every table, but the biology is thin, as you'll see. The numbers of MaxBin2, Nonpareil and all that follows from the genome catalogue come from before version 0.4.74, whose fixes change them. This part will get them from a new run.

Most tools ran there with the pipeline's own rules, also metaSPAdes in a copy of the project. Three of them used a smaller database than a real run does, and the text says so each time: Kraken2 with the Standard-8 database, Bakta with its light database, and sylph with a database of only the run's own genome. FastQC ran on a native Java, as emulation made it too slow. @sec-tutorial-waiting lists what still needs the complete run on a cluster, and those sections will be added from it.
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

### FastQC on all reads {#sec-tutorial-fastqc-all}

The two reports above come from 100,000 reads, as FastQC took about 16 minutes per file under emulation. So for all the reads, `book/examples/real_tools/native_fastqc.sh` runs the FastQC of the pipeline's image on a native Java. It's the same program, version 0.12.1, without the emulation. There are 18 files: 6 of raw reads, 6 after fastp and 6 clean ones. This command lists every mark that isn't a `PASS`:

```text
$ for f in results/reads/*_fastqc.zip results/preprocess/fastp/*_fastqc.zip results/preprocess/bowtie2/nonphix/*_fastqc.zip; do unzip -p $f '*/summary.txt' | awk -F '\t' -v f=$f '$1 != "PASS" {print $1, $2, f}'; done | sed 's#results/##; s#_fastqc.zip##'
FAIL Per sequence GC content reads/ERR2019410.lib1_1
WARN Overrepresented sequences reads/ERR2019410.lib1_1
FAIL Per sequence GC content reads/ERR2019410.lib1_2
FAIL Per sequence GC content reads/ERR2019412.lib1_1
FAIL Per sequence GC content reads/ERR2019412.lib1_2
FAIL Per base sequence content reads/ERR2019415.lib1_1
FAIL Per sequence GC content reads/ERR2019415.lib1_1
FAIL Per base sequence content reads/ERR2019415.lib1_2
FAIL Per sequence GC content reads/ERR2019415.lib1_2
[...]
FAIL Per sequence GC content preprocess/fastp/ERR2019410.lib1_1
WARN Sequence Length Distribution preprocess/fastp/ERR2019410.lib1_1
[...]
FAIL Per base sequence content preprocess/bowtie2/nonphix/ERR2019415.lib1_2
FAIL Per sequence GC content preprocess/bowtie2/nonphix/ERR2019415.lib1_2
WARN Sequence Length Distribution preprocess/bowtie2/nonphix/ERR2019415.lib1_2
```

The output is shortened here. All 18 files follow the same pattern, and each mark tells you something different:

- **Per sequence GC content fails in all 18 files.** @sec-tool-fastqc explains why this is normal for a community of many organisms. Note one detail: on 100,000 trimmed reads the same mark was a `WARN`, and on all the reads it's a `FAIL`. The reads didn't get worse. A mark depends on the amount of data, so read the plot and not the colour.
- **The overrepresented sequences appear only in the raw reads of `ERR2019410`, read 1.** After fastp, the warning is gone, as above.
- **The length distribution warns after fastp**, because trimming makes the reads differ in length, which is what it should do.
- **Per base sequence content fails only in `ERR2019415`**, and in all three steps of it. Neither fastp nor host removal changes it, so it comes with this sample or its library. This is the one mark that the small subset didn't show, and it's worth a look at the plot before you trust the sample.

The total confirms that the report covers everything:

```text
$ unzip -p results/reads/ERR2019410.lib1_1_fastqc.zip '*/fastqc_data.txt' | sed -n '/^>>Basic Statistics/,/^>>END_MODULE/p' | cut -f 1,2
>>Basic Statistics	pass
#Measure	Value
Filename	ERR2019410.lib1_1.fq.gz
File type	Conventional base calls
Encoding	Sanger / Illumina 1.9
Total Sequences	1000000
Total Bases	101 Mbp
Sequences flagged as poor quality	0
Sequence length	101
%GC	44
>>END_MODULE
```

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

@sec-module-read-annotate explains this stage. Many of its databases are large. Here we look at two tools that need little, at Kraken2 first with a toy database and then with a real one, at DIAMOND, phyloFlash, and at sylph with a very small database of its own.

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

### Kraken2 and Krona, with a real database {#sec-tutorial-kraken2-real}

The complete Standard database needs about 140 GB of memory. Ben Langmead's collection also has Standard-8, from the same date and with the same kinds of genomes, but capped at 8 GB, so that Kraken2 keeps only a part of the k-mers. This is small enough to run the pipeline's own rules on all the reads, with `extra_tools.sh <project> kraken2`. The results are real, but they aren't what the complete database gives.

```text
$ cat results/read_annotate/kraken2/standard_08gb/ERR2019410.lib1.log
Loading database information... done.
935567 sequences (188.83 Mbp) processed in 102.557s (547.3 Kseq/m, 110.47 Mbp/m).
  31464 sequences classified (3.36%)
  904103 sequences unclassified (96.64%)
```

Two things to note. There are 935,567 pairs and not the 933,448 clean ones, as the rule reads the reads after fastp, as @sec-module-read-annotate shows. And only 3.36% of them get a name. The other two samples are in the same range:

```text
$ grep -h 'sequences classified' results/read_annotate/kraken2/standard_08gb/*.log
  31464 sequences classified (3.36%)
  30439 sequences classified (3.20%)
  22570 sequences classified (2.36%)
```

Don't read this as "97% of the rumen is unknown". It says that this database, with mostly well-studied organisms and with most of its k-mers left out, finds little in a rumen. A complete database should find more, and the complete run on a cluster will show how much. This is why a real project uses a database that fits its environment.

The top of the report is the same format as with the toy database, but now it has a real community:

```text
$ head -n 12 results/read_annotate/kraken2/standard_08gb/ERR2019410.lib1.report
 96.64	904103	904103	U	0	unclassified
  3.36	31464	2016	R	1	root
  3.15	29444	73	R1	131567	  cellular organisms
  3.10	28990	2166	D	2	    Bacteria
  2.21	20668	3	D1	1783270	      FCB group
  2.07	19328	15	D2	68336	        Bacteroidota/Chlorobiota group
  2.06	19303	477	P	976	          Bacteroidota
  1.98	18526	9	C	200643	            Bacteroidia
  1.98	18498	577	O	171549	              Bacteroidales
  1.78	16643	1000	F	171552	                Prevotellaceae
  0.74	6924	883	G	838	                  Prevotella
  0.34	3195	242	G1	2638335	                    unclassified Prevotella
```

Most of what it recognizes is Bacteroidota, and within it Prevotellaceae. The genera, sorted by their clade:

```text
$ awk -F '\t' '$4 == "G"' results/read_annotate/kraken2/standard_08gb/ERR2019410.lib1.report | sort -t $'\t' -k 2,2nr | head -n 8
  0.74	6924	883	G	838	                  Prevotella
  0.65	6107	3255	G	2974251	                  Segatella
  0.25	2306	0	G	558436	                  Xylanibacter
  0.14	1337	0	G	832	                Fibrobacter
  0.06	549	0	G	2815786	                  Sodaliphilus
  0.04	399	88	G	816	                  Bacteroides
  0.04	382	7	G	906	                Megasphaera
  0.04	373	5	G	2767893	                Lentilactobacillus
```

*Prevotella*, *Segatella* and *Xylanibacter* belong together here, as the last two were split off from *Prevotella* quite recently. *Fibrobacter* and *Megasphaera* are well-known rumen genera, so at least the picture is plausible.

Krona then drew a chart of this report with the pipeline's rule. It has this many levels and taxa:

```text
$ grep -c '<node name=' results/read_annotate/krona/standard_08gb/ERR2019410.lib1.html
3267
```

### DIAMOND with CAZy {#sec-tutorial-diamond}

This is the first tool here with its real, complete database. `extra_tools.sh <project> diamond` downloads it. It took 34 minutes per library under emulation, for nearly 2 million reads against a protein database. DIAMOND's log ends with this, for one of the files of a sample:

```text
$ tail -n 3 results/read_annotate/diamond/cazy_ERR2019410_lib1.log
Total time = 1028.16s
Reported 43776 pairwise alignments, 43776 HSPs.
43776 queries aligned.
```

The output has one line per read with a hit. The columns are those of BLAST, as @sec-tool-diamond lists:

```text
$ head -n 3 results/read_annotate/diamond/cazy/ERR2019410.lib1_R1.out
ERR2019410.11/1	AHW60282.1|GH43_19|GH43_34	64.5	31	10	1	91	2	580	610	2.99e-04	40.8
ERR2019410.34/1	QUO23328.1|GT51	71.0	31	9	0	7	99	450	480	2.20e-07	49.7
ERR2019410.40/1	UWP19973.1|GT5	84.8	33	5	0	100	2	144	176	5.53e-15	71.2
```

Read the first line: read 11 hits the protein `AHW60282.1`, with 64.5% identity over 31 amino acids. A read of 101 bases can't give an alignment much longer than 33 amino acids, so short alignments are all you get here. And the protein belongs to two families at once, `GH43_19` and `GH43_34`.

Those two labels are the reason for having two summary tables. In `summary_a.tsv`, a read counts fully for each label of its hit. In `summary_b.tsv`, it's shared out among them:

```text
$ head -n 3 results/read_annotate/diamond/cazy/summary_a.tsv | cut -f 1-3
Feature	ERR2019410.lib1_R1.out	ERR2019410.lib1_R2.out
2.4.1.20	7	13
2.4.1.241	3	2
```

```text
$ head -n 3 results/read_annotate/diamond/cazy/summary_b.tsv | cut -f 1-3
Feature	ERR2019410.lib1_R1.out	ERR2019410.lib1_R2.out
2.4.1.20	3.5	6.5
2.4.1.241	1.5	1
```

Adding up a column shows the difference clearly:

```text
$ for f in a b; do awk -F '\t' -v f=$f 'NR > 1 && $2 != "NA" {s += $2} END {print "summary_" f, s}' results/read_annotate/diamond/cazy/summary_$f.tsv; done
summary_a 51154
summary_b 43797
```

There are 43,797 lines in the file, so the sum of table b is the number of reads with a hit, and the sum of table a is higher, at 51,154. Use a to say how many reads touch a family, and b when the numbers have to add up, as in shares. That's 4.7% of the reads with a hit to a CAZy protein.

The most frequent labels over all files are these. `GT` stands for glycosyltransferases, `GH` for glycoside hydrolases, and `CBM` for carbohydrate-binding modules:

```text
$ tail -n +2 results/read_annotate/diamond/cazy/summary_a.tsv | awk -F '\t' '{s = 0; for (i = 2; i <= NF; i++) if ($i != "NA") s += $i; print s, $1}' | sort -nr | head -n 5
25757 GT2
14493 GH2
14109 GT4
12161 GH3
6157 CBM48
```

### sylph, with a small database {#sec-tutorial-sylph}

A real sylph database needs more memory than this computer has. So `extra_tools.sh <project> sylph` sketches its own: only the one genome from dRep in this run. This is enough to see real output, and it takes 9 seconds per library. It can't show a real profile:

```text
$ cut -f 2,3,4,5,6,8,12 results/read_annotate/sylph/ERR2019410.lib1.profiling.tsv | sed 's#results/assemble/drep/dereplicated_genomes/##'
Genome_file	Taxonomic_abundance	Sequence_abundance	Adjusted_ANI	Eff_cov	Eff_lambda	Containment_ind
coasm:bin_000001.fa.gz	100.0000	100.0000	99.85	3.263	HIGH	6556/6874
```

Each column has something to teach:

- **The abundance is 100%**, though the genome has only a small share of the reads. This is the pitfall of @sec-tool-sylph, in its purest form: the percentages refer to what sylph detected, and it detected one genome.
- **The ANI is 99.85%**, as it should be for a genome assembled from these reads.
- **The effective coverage is 3.26**. `Containment_ind` says that 6,556 of the sketch's 6,874 k-mers are in the reads.
- **`Eff_lambda` is `HIGH`, and not a number.** That's what sylph writes when the coverage is high.

The other two samples have a lower coverage:

```text
$ cut -f 3,5,6,8,12 results/read_annotate/sylph/ERR2019412.lib1.profiling.tsv
Taxonomic_abundance	Adjusted_ANI	Eff_cov	Eff_lambda	Containment_ind
100.0000	100.00	0.582	0.582	3086/6874
```

```text
$ cut -f 3,5,6,8,12 results/read_annotate/sylph/ERR2019415.lib1.profiling.tsv
Taxonomic_abundance	Adjusted_ANI	Eff_cov	Eff_lambda	Containment_ind
100.0000	99.05	0.215	0.215	991/6874
```

The order agrees with the reads that CoverM counts on this genome in @sec-tutorial-quantify, and it shows the strength of sylph: at a coverage of 0.2, with only 991 of the k-mers found, it still gives an ANI, of 99.05%. Its interval for that is 98.46 to 99.65%, in a column not shown here, so the third sample probably has a slightly different strain.

The value `HIGH` also found a real bug, as @sec-tutorial-found describes.

### phyloFlash {#sec-tutorial-phyloflash}

phyloFlash ran with its real database, SILVA 138.2, and it was a pleasant surprise. It fits into 7 GB of memory on these reads, and it took about 6 minutes per library:

```text
$ grep -m 1 'Walltime' results/read_annotate/phyloflash/ERR2019410_lib1.phyloFlash.log
[00:36:18] Walltime used: 6.30 minutes with 8 CPU cores
```

Its summary is in a file in its archive:

```text
$ tar -xzOf results/read_annotate/phyloflash/ERR2019410_lib1.phyloFlash.tar.gz ERR2019410_lib1.phyloFlash.report.csv | sed -n '8,12p;18,21p'
input reads,933448
input read segments,1866896
mapped SSU reads,1586
mapped SSU read segments,2671
mapping ratio,0.170
NTUs observed once,8
NTUs observed twice,4
NTUs observed three or more times,32
NTU Chao1 richness estimate,40.000
```

So 0.17% of the read pairs come from small-subunit rRNA genes. This is the small share that @sec-tool-phyloflash warns about, and it leaves about 1,600 pairs to work with. They give this composition, at the level of orders:

```text
$ tar -xzOf results/read_annotate/phyloflash/ERR2019410_lib1.phyloFlash.tar.gz ERR2019410_lib1.phyloFlash.NTUabundance.csv | head -n 8
Bacteria;Bacteroidota;Bacteroidia;Bacteroidales,745
Bacteria;Pseudomonadota;Gammaproteobacteria;Enterobacterales,169
Bacteria;Bacillota;Clostridia;Lachnospirales,149
Bacteria;(Bacteria);(Bacteria);(Bacteria),124
Bacteria;Bacillota;Clostridia;Oscillospirales,59
Eukaryota;SAR;Alveolata;Ciliophora,42
Bacteria;Bacillota;Negativicutes;Veillonellales-Selenomonadales,36
Bacteria;Fibrobacterota;Fibrobacteria;Fibrobacterales,34
```

Compare this with Kraken2 above. Two very different methods and databases both put Bacteroidales first. And here you see something that Kraken2's database barely has, the eukaryotes:

```text
$ for l in ERR2019410 ERR2019412 ERR2019415; do tar -xzOf results/read_annotate/phyloflash/${l}_lib1.phyloFlash.tar.gz ${l}_lib1.phyloFlash.NTUabundance.csv | grep -i '^Eukaryota' | head -n 3; echo; done
Eukaryota;SAR;Alveolata;Ciliophora,42
Eukaryota;(Eukaryota);(Eukaryota);(Eukaryota),6
Eukaryota;Amorphea;Obazoa;Opisthokonta,3

Eukaryota;SAR;Alveolata;Ciliophora,54
Eukaryota;(Eukaryota);(Eukaryota);(Eukaryota),5
Eukaryota;SAR;(SAR);(SAR),3

Eukaryota;SAR;Alveolata;Ciliophora,127
Eukaryota;(Eukaryota);(Eukaryota);(Eukaryota),20
Eukaryota;SAR;(SAR);(SAR),8
```

Ciliates are what you'd expect in a rumen, and they appear in all three samples. Remember this when we come to the eukaryote stage. The reads here don't depend on an assembly, so this is good independent support.

Two warnings from this output.

**Don't use its Chao1 value.** In the first library, phyloFlash observed 8 + 4 + 32 = 44 taxa, and it reports a Chao1 richness of 40. An estimate of the true number of taxa can't be lower than the number seen. Here are the three values for all libraries:

```text
$ for l in ERR2019410 ERR2019412 ERR2019415; do tar -xzOf results/read_annotate/phyloflash/${l}_lib1.phyloFlash.tar.gz ${l}_lib1.phyloFlash.report.csv | grep '^NTU' | cut -d , -f 2 | xargs; done
8 4 32 40.000
11 7 27 35.643
15 4 30 58.125
```

All three fit "taxa seen at least three times + $f_1^2 / (2 f_2)$", where $f_1$ and $f_2$ are the taxa seen once and twice. So 32 + 64/8 = 40, 27 + 121/14 = 35.643, and 30 + 225/8 = 58.125. The usual Chao1 starts from all taxa seen, which would give 52, 53.6 and 77.1. The report of the pipeline therefore shows the number of observed taxa, and not this value.

**Its assembly step failed, and don't believe the reason that it gives.** This doesn't stop phyloFlash, which exits with 0:

```text
$ grep -A 1 'SPAdes exited' results/read_annotate/phyloflash/ERR2019410_lib1.phyloFlash.log
[00:36:16] SPAdes exited with error, this may happen if no sequences were
	   assembled Possible causes include coverage per sequence too low
```

With so few reads, that sounds convincing. But the log of SPAdes itself, in the archive, says what really happened:

```text
$ tar -xzOf results/read_annotate/phyloflash/ERR2019410_lib1.phyloFlash.tar.gz ERR2019410_lib1.spades.out | grep -m 1 'qemu'
qemu: uncaught target signal 11 (Segmentation fault) - core dumped
```

So it's a crash under emulation, in the read correction of SPAdes, and it says nothing about the data. All that you get from this run therefore comes from the mapped reads, and there are no full-length rRNA sequences. On a cluster, look in this log as well if the assembled sequences are missing. It's a good example of a general rule: when a tool suggests a cause, check it.

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

### metaSPAdes instead of MEGAHIT {#sec-tutorial-metaspades}

The default assembler of this project is MEGAHIT, but metaSPAdes fits too, on these small data. `extra_tools.sh <project> spades <new project>` copies the project and sets `assembler: metaspades`. This changes which assemblies exist, so it's a project of its own. It ran with the pipeline's rule, on 7 GB of memory, in 17 minutes for `ERR2019410` and in 59 minutes for the co-assembly.

The first line to look at in its log confirms a problem of the rule that @sec-tool-metaspades describes:

```text
$ grep -m 1 'Memory limit' results/assemble/metaspades/coasm.log
  Memory limit (in Gb): 6500
```

The job has 6,500 MB, and the rule passes that number to `-m`, which metaSPAdes reads as gigabytes. So it believes that it has 6.5 TB, and it never limits itself. In this run it didn't matter, as it stayed within the 7 GB of the container.

The results look very different from MEGAHIT's at first sight:

```text
$ gzip -dc results/assemble/metaspades/ERR2019410.fa.gz | awk '/^>/ {if (l) print l; l = 0; next} {l += length($0)} END {print l}' | sort -nr | awk '{n++; s += $1; if ($1 >= 200) a++; if ($1 >= 500) b++; if ($1 >= 1000) c++; if ($1 >= 1500) d++; if ($1 >= 1500) e += $1} END {print "contigs", n, "bases", s; print ">= 200", a; print ">= 500", b; print ">= 1000", c; print ">= 1500", d, "bases", e}'
contigs 24362 bases 9221847
>= 200 23781
>= 500 3134
>= 1000 1091
>= 1500 625 bases 1705476
```

```text
$ gzip -dc results/assemble/metaspades/coasm.fa.gz | awk '/^>/ {if (l) print l; l = 0; next} {l += length($0)} END {print l}' | sort -nr | awk '{n++; s += $1; if ($1 >= 200) a++; if ($1 >= 500) b++; if ($1 >= 1000) c++; if ($1 >= 1500) d++; if ($1 >= 1500) e += $1} END {print "contigs", n, "bases", s; print ">= 200", a; print ">= 500", b; print ">= 1000", c; print ">= 1500", d, "bases", e}'
contigs 94759 bases 30435788
>= 200 92558
>= 500 7697
>= 1000 1701
>= 1500 914 bases 2663152
```

| Assembly | Assembler | All contigs | N50 | Contigs of at least 1,500 bases | Their bases |
|----------|-----------|-------------|-----|---------------------------------|-------------|
| `ERR2019410` | MEGAHIT | 549 | 2,415 | 549 | 1.37 Mb |
| `ERR2019410` | metaSPAdes | 24,362 | 351 | 625 | 1.71 Mb |
| `coasm` | MEGAHIT | 900 | 2,858 | 900 | 2.48 Mb |
| `coasm` | metaSPAdes | 94,759 | 289 | 914 | 2.66 Mb |

If you compare only the columns of all contigs and N50, metaSPAdes looks far worse: an N50 of 289 against 2,858. **This comparison isn't fair.** MEGAHIT has `min_contig_len: 1500` in `params.yaml`, and the rule for metaSPAdes has no minimum length, so it keeps every short contig. Compare only contigs of the same minimum length, as in the last two columns, and metaSPAdes has a little more than MEGAHIT here.

For the pipeline, this has a consequence. Everything downstream of `results/assemble/metaspades/` gets those tens of thousands of short contigs, unless a tool has its own limit, and as @sec-tutorial-4cac shows, this can decide whether a job fits into memory.

The working folder goes into an archive, since it holds so many files, and 4CAC later needs the graph from it:

```text
$ ls -l results/assemble/metaspades | awk '{print $5, $9}' | grep -E 'coasm|ERR2019410.fa.gz|ERR2019410.tar.gz'
2727751 ERR2019410.fa.gz
74330275 ERR2019410.tar.gz
9033201 coasm.fa.gz
158354 coasm.log
256472735 coasm.tar.gz
136260379 coasm_R1_concat.fastq.gz
139969490 coasm_R2_concat.fastq.gz
```

So the archive of a co-assembly is 28 times as large as the assembly itself. Plan the disk for it. The two pooled read files are temporary, and normally Snakemake deletes them. They stayed here because this run named the assemblies directly as targets.

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

### DIAMOND with HydDB {#sec-tutorial-hyddb}

The same search for hydrogenases with DIAMOND, as a protein search against HydDB, with its real database and in about a second:

```text
$ tail -n 2 results/contig_annotate/diamond/hyddb_coasm.log
Reported 0 pairwise alignments, 0 HSPs.
0 queries aligned.
```

No hits, in line with HMMER above: these few proteins have no real hydrogenases. An empty result like this is a valid result, and the rule and the report take it as one.

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

@sec-module-mag-annotate explains this stage. Most of it needs large databases. QUAST needs none, so we start with it, and then come CheckM2, Bakta with its light database, and Proteinortho:

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

### CheckM2 {#sec-tutorial-checkm2}

CheckM2 ran with its real database, in 18 minutes:

```text
$ cut -f 1,2,3,4,6 results/mag_annotate/checkm2/quality_report.tsv
Name	Completeness	Contamination	Completeness_Model_Used	Coding_Density
coasm:bin_000001.fa	61.5	0.09	Gradient Boost (General Model)	0.871
```

By the rules of @sec-tool-checkm2, this is a medium-quality genome: at least 50% complete and with less than 10% contamination. MAGScoT had estimated 57.5% and 2.9% for the same bin, from its marker genes. So the two agree on the completeness, within a few percent. Their estimates of contamination differ, and with so little data you shouldn't read much into the difference. Both numbers are estimates. For your report, use CheckM2's, which were made for this purpose.

CheckM2 chose its general model, one of the two that @sec-tool-checkm2 describes. The name of the genome has lost its `.gz`, so a table you join with this one needs the name without it, which the report takes care of.

### Bakta, with the light database {#sec-tutorial-bakta}

The full database of Bakta is 73 GB as a download. Its light database has 1.4 GB, with the same tool but far fewer known proteins. So `extra_tools.sh <project> bakta` uses that, and it took 21 minutes:

```text
$ cat results/mag_annotate/bakta/bakta.txt
Sequence(s):
Length: 1647187
Count: 554
GC: 56.9
N50: 3208
N ratio: 0.0
coding density: 69.6

Annotation:
tRNAs: 16
tmRNAs: 1
rRNAs: 3
ncRNAs: 4
ncRNA regions: 3
CRISPR arrays: 0
CDSs: 1539
pseudogenes: 0
hypotheticals: 1180
signal peptides: 0
sORFs: 0
gaps: 0
oriCs: 0
oriVs: 0
oriTs: 0

Bakta:
Software: v1.9.3
Database: v5.1, light
DOI: 10.1099/mgen.0.000685
URL: github.com/oschwengers/bakta
```

The first lines are the numbers from QUAST again, 554 contigs and 1,647,187 bases, which is a good check that this is the same catalogue. Of the 1,539 genes, 1,180 are hypothetical, which is 77%. The light database has far fewer known proteins, so don't quote this number, as it says little about how well the organism is known. The complete run will show the share with the full database.

`CRISPR arrays: 0` isn't a result either, as the rule skips this step. And Bakta calls the contigs `contig_1` and so on, so the names aren't those of the pipeline:

```text
$ sed -n '6,8p' results/mag_annotate/bakta/bakta.tsv
#Sequence Id	Type	Start	Stop	Strand	Locus Tag	Gene	Product	DbXrefs
contig_1	cds	470	721	-	MGKAHE_00005		hypothetical protein
contig_1	cds	1001	1498	-	MGKAHE_00010		hypothetical protein
```

The contigs keep their order, so `contig_1` is the first contig of the input.

One more real lesson comes from this step. The first attempt ran for 19 minutes, and then it stopped at the search for resistance genes, with this message in its log: `amrfinder error! error code: 1. Please, try 'amrfinder_update --force_update --database ...'`. The AMRFinderPlus database in the archive doesn't fit the AMRFinderPlus of the image. After the command that the message suggests, it ran through, and it found one gene:

```text
$ grep 'EXPERT-AMRFINDER' results/mag_annotate/bakta/bakta.log | cut -d ' ' -f 3-
INFO - EXPERT-AMRFINDER - found=1
```

If you see this in your own run, you have the same problem with your database, and the same command solves it.

### Proteinortho {#sec-tutorial-proteinortho}

Proteinortho compares the proteins from Bakta's run on the MAGs of each assembly. Here there are two assemblies, and each has one set:

```text
$ head -n 3 results/mag_annotate/proteinortho/proteinortho.proteinortho.tsv
# Species	Genes	Alg.-Conn.	bakta_ERR2019410.faa	bakta_coasm.faa
2	3	0.33	KEMBFC_00025	MGKAHE_01270,MGKAHE_07345
2	3	0.33	KEMBFC_00030	MGKAHE_01955,MGKAHE_01265
```

Read the first group: one protein from the assembly of `ERR2019410` and two from the co-assembly are orthologs. A connectivity of 0.33 means that the group is only loosely connected.

```text
$ sed -n '/^# number of groups for each/,/^$/p' results/mag_annotate/proteinortho/proteinortho.proteinortho-graph.summary
# number of groups for each input species:
bakta_ERR2019410.faa	793	100%
bakta_coasm.faa	793	100%
```

All 793 groups have members in both sets. Before you get excited about a core of 100%, remember what these sets are. The reads of `ERR2019410` are part of the co-assembly as well, so the two sets aren't independent, and proteins found in only one set can't form a group at all. A comparison like this means more with independent genomes.

## Stage `eukaryote` {#sec-tutorial-eukaryote}

@sec-module-eukaryote explains this stage. It has three tools, so that you can compare their answers. We start with Tiara, on the assemblies of MEGAHIT:

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

### Tiara and 4CAC on metaSPAdes {#sec-tutorial-4cac}

4CAC needs the assembly graph of metaSPAdes, so it ran in the project of @sec-tutorial-metaspades. Tiara ran there too, so that the two can be compared on the same contigs. Tiara only looks at contigs of at least 1,000 bases, because of `min_len` in `params.yaml`:

```text
$ sed -n '1,7p' results/eukaryote/tiara/log_ERR2019410.tsv
First iteration statistics:
	archaea: 177
	bacteria: 827
	eukarya: 49
	organelle: 1
	prokarya: 28
	unknown: 9
```

That's 1,091 contigs, the same number as in the count of contigs of at least 1,000 bases above. 4CAC looks at all the contigs, and it ran in only 2 minutes. Its table has a line per contig:

```text
$ head -n 3 results/eukaryote/4cac/ERR2019410.tsv | cut -f 1,2,3,6,7
contig_id	node_id	class	prokar_score	eukar_score
ERR2019410:bin_NA@contig_00000001	NODE_1_length_13170_cov_2.378040	prokarya	0.9285428	0.00038095997
ERR2019410:bin_NA@contig_00000002	NODE_2_length_12608_cov_2.439417	prokarya	0.34207305	0.0016502232
```

The two names in a line come from `workflow/scripts/fourcac_to_contig_ids.py`, which repeats the numbering of the assembly rule. This is the place where a mistake would silently put every label on the wrong contig. The name of metaSPAdes contains the length of the contig, so that can be checked on real data, and no contig has another length:

```text
$ python3 "book/examples/real_tools/check_4cac_ids.py" results/eukaryote/4cac/ERR2019410.tsv results/assemble/metaspades/ERR2019410.fa.gz
contigs in the assembly: 24362
lines in the table: 24362
not in the assembly: 0
with another length: 0
```

The classes of all contigs:

```text
$ cut -f 3 results/eukaryote/4cac/ERR2019410.tsv | tail -n +2 | sort | uniq -c | sort -nr
11402 prokarya
9106 uncertain
2881 eukarya
 972 phage
   1 plasmid
```

A class of `uncertain` for over a third of the contigs is an honest answer for contigs of a few hundred bases. Most of them are too short for a real signal. And how much did the assembly graph help? Its log says:

```text
$ grep -E 'contigs contained|corrected|propagation' results/eukaryote/4cac/ERR2019410.log
24362 contigs contained in the path file: results/eukaryote/4cac/ERR2019410/scaffolds.paths
0 edge need to be corrected!
Complete the correction step. 0.000 classified edges were corrected, and 0.000 with >2 supporting neighbors!
Complete the propagation step. 210.000 uncertain edges were classified, and 21.000 with >1 supporting neighbors!
```

Very little. At such a low coverage, the graph falls apart into pieces with few neighbors, and these are what the graph step needs. So here 4CAC mostly shows the first step, the classifier on the sequence alone. Expect more from a deeper assembly.

Now the comparison on the 1,091 contigs that both have seen, with Tiara's labels in the rows, and those of 4CAC in the columns:

```text
$ python3 "book/examples/real_tools/compare_labels.py" results/eukaryote/tiara/ERR2019410.tsv results/eukaryote/4cac/ERR2019410.tsv
Tiara	eukarya	phage	prokarya	uncertain
archaea	17	5	129	26
bacteria	54	19	653	101
eukarya	24	8	6	11
organelle	0	0	1	0
prokarya	4	0	19	5
unknown	1	2	5	1
contigs compared: 1091
```

On the large scale they agree: most contigs that Tiara calls bacteria or archaea are also prokaryotes for 4CAC. On the eukaryotes they do not. Tiara calls 49 contigs eukaryotic, and 4CAC 100. Only 24 of these are in both. That's why this module has more than one tool: **a contig labelled eukaryotic by one tool alone is a suggestion, and not a finding.** Those 24 are the ones to look at first, and phyloFlash's ciliates from @sec-tutorial-phyloflash are independent support that eukaryotes are in the data at all.

4CAC on the co-assembly didn't work here, which is a result as well. It has 94,759 contigs, four times as many as `ERR2019410`, and the k-mer counting of 4CAC holds them in memory:

```text
$ tail -n 1 results/eukaryote/4cac/coasm.log.try3
ConnectionResetError: [Errno 104] Connection reset by peer
```

With 8 processes, the system killed the program in that step. With 2 processes, as here, one of the helper processes disappeared. The log doesn't say why, but the container has a limit of 7 GB, and the smaller assembly fits. The rule starts with the resource set `medium`, which has 160 GB, so this shouldn't happen on a cluster unless the assembly is very large. Note the connection to @sec-tutorial-metaspades: 92% of those contigs are shorter than 500 bases, and the rule for metaSPAdes keeps them.

## The reports of this run {#sec-tutorial-reports}

The reports in `Rreports/` sum up all of the above, and @sec-module-report explains them. For this run, `tests/reports/run_test.sh` compares their tables with the numbers that this chapter took from the tools' own files. For example, the preprocess report has the 933,448 clean pairs of `ERR2019410`, and the assemble report has 900 contigs in the co-assembly with an N50 of 2,858.

Two things are different on a real cluster. Here, the reports can't show any memory use or CPU time, and they say so, because Snakemake's benchmark sees only Docker's client process when the containers run through the stand-in for Apptainer of this chapter. And the reports describe only what has run here: the sections of tools from @sec-tutorial-waiting say that they have no output.

The reports were also tested by these runs. Until then, their parsers for many tools followed only the documentation of the tools, and this is what real output showed, as the next section lists.

## Two runs of the same project {#sec-tutorial-repeat}

How reproducible is all this? To find out, the same steps ran a second time, in a new project, with the same reads and the same number of threads. The clean reads are identical, byte for byte. Here's the first read file of `ERR2019410` in each of the two projects:

```text
$ cd "first" && gzip -dc results/preprocess/bowtie2/decontaminated_reads/ERR2019410.lib1_1.fq.gz | md5
b0a3a6901857fdb0231b2c6ef181bd47
```

```text
$ cd "second" && gzip -dc results/preprocess/bowtie2/decontaminated_reads/ERR2019410.lib1_1.fq.gz | md5
b0a3a6901857fdb0231b2c6ef181bd47
```

So everything up to here gave the same result. The assemblies don't:

```text
$ python3 "book/examples/real_tools/compare_assemblies.py" "first/results/assemble/megahit/coasm.fa.gz" "second/results/assemble/megahit/coasm.fa.gz"
contigs: 900 and 901
bases: 2480429 and 2481971
same contigs in the same order: False
only in the first: 0 contigs, 0 bases
only in the second: 1 contigs, 1542 bases
```

```text
$ python3 "book/examples/real_tools/compare_assemblies.py" "first/results/assemble/megahit/ERR2019410.fa.gz" "second/results/assemble/megahit/ERR2019410.fa.gz"
contigs: 549 and 549
bases: 1370369 and 1370369
same contigs in the same order: False
only in the first: 1 contigs, 2192 bases
only in the second: 1 contigs, 2192 bases
```

With the same input and settings, MEGAHIT made one more contig in the co-assembly, and in the other assembly a contig of the same length with a different sequence. The contigs also came out in another order. This small difference is passed on. Contig number 500 in one run isn't contig number 500 in the other, and MetaBAT2 found another bin:

```text
$ ls "first/results/assemble/metabat2/coasm" "second/results/assemble/metabat2/coasm"
second/results/assemble/metabat2/coasm:
bin.1.fa.gz
bin.2.fa.gz

first/results/assemble/metabat2/coasm:
bin.1.fa.gz
```

The lesson isn't that the tools are bad. There's a practical lesson for your work: **from the assembly on, keep the files of the run that you report.** Running it again gives you very similar results, but not the same ones, so you can't reproduce a table exactly by running the pipeline once more, and contig names aren't stable between runs.

And this is why the test of @sec-tests-in-repo gives these steps a tolerance. Before this second run, it expected exactly 2,828 genes and exactly 1 bin of MetaBAT2, and both failed. With the corrected tolerances, all values agree:

```text
$ "tests/real_tools/check_results.py" "second"
All 41 values as expected
```

## What this run found {#sec-tutorial-found}

Before these real runs, the rewritten pipeline had only been tested with stand-ins for its tools. Its first contact with the real ones found these problems, all of which are fixed now:

| What happened | Why stand-ins missed it |
|---------------|-------------------------|
| The clean reads were cut off, and MEGAHIT and Nonpareil failed on them with `unexpected end of file` | The stand-in tools finished at once, so nothing was still being written when the rule ended |
| `nonpareil.tsv` had no values at all when one library had too little coverage | Only the real R package returns this special form of table |
| dRep reported a failure of CheckM, but exited with 0 | A stand-in doesn't do this |
| sylph writes `HIGH` in `Eff_lambda` at high coverage and a number otherwise, and with that the whole report of `read_annotate` couldn't be made | The test's made-up table had only numbers |
| The report counted the labels of DIAMOND's hits as reads, 51,154 instead of 43,797 | The made-up table had one label per hit |
| The report said that the sum of sylph's sequence abundance shows how much of the reads the database explains. It's always 100% | The made-up numbers looked plausible, and they added up to less |
| The light database of Bakta has an AMRFinderPlus database that doesn't fit the image, and Bakta stops at this step after the others have run | Only a real database shows this |

Reading the rules while writing this book found more, like the wrong columns for Krona. A dry run of each target found that `contig_annotate__featurecounts` couldn't start.

The lesson is general: **stand-ins test your plumbing, and only real tools test your assumptions about them.** @sec-testing returns to this. The numbers of this run are now stored as a test, as @sec-tests-in-repo describes.

## What's still waiting for the complete run {#sec-tutorial-waiting}

These parts have no real output on these data in this book yet. When the complete run on a cluster is done, its archive from `tests/real_run/collect.py` will fill them in. Their tool chapters in Part II describe the output formats.

| Stage | Tools | Why they couldn't run here |
|-------|-------|----------------------------|
| `read_annotate` | SingleM, MetaPhlAn | Both crash under emulation, already at `--version`, with exit code 139 |
| `read_annotate` | HUMAnN | Its databases are 53 GB as a download |
| `read_annotate` | Kraken2 and Krona with the complete database | About 140 GB of memory. Shown here with Standard-8 |
| `read_annotate` | sylph with a real database | Memory. Shown here with a database of one genome |
| `contig_annotate` | eggNOG-mapper, eggNOG 7 | Their databases |
| `mag_annotate` | GTDB-Tk, PhyloPhlAn, DRAM, eggNOG-mapper | Their databases, of up to 520 GB |
| `mag_annotate` | CAMPER | It works on the output of DRAM |
| `mag_annotate` | Bakta with the full database | 73 GB as a download. Shown here with the light one |
| `eukaryote` | 4CAC on the co-assembly | Memory, with 94,759 contigs. Shown here on `ERR2019410` |
| `eukaryote` | REMAG | REMAG_WAITING |

Run times and memory on real hardware will come from that run too, from `sacct`.
