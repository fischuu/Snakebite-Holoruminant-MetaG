# Rule reference {#sec-rule-reference}

This appendix is generated from the rule files by `book/tools/rule_reference.py`. Do not edit it by
hand. Paths are shown as they are written in the rules, so they use the path constants of
`workflow/rules/folders.smk`, which @sec-path-constants explains.

Rules without their own entry in `config/escalation.yaml` use the default escalation
(`small, medium, large`).

## Module `reads`

### `reads/__main__.smk`

**`reads`**

Symlink the raw reads and run FastQC on them

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.reads__link.input`
- input: `rules.reads__fastqc.input`
- input: `PIPELINE_REPORT / "reads.pdf"`

### `reads/fastqc.smk`

**`reads__fastqc`**

Aggregate FastQC reports for every raw forward/reverse read file

Target rule: it runs nothing itself and only asks for these files.

- input: `[READS / f"{sample_id}.{library_id}_{end}_fastqc.zip" for sample_id, library_id in SAMPLE_LIBRARY for end in (1, 2)]`

### `reads/link.smk`

**`reads__link__run`**

Symlink one sample's raw reads under a normalized {sample}.{library}_{1,2}.fq.gz name

- input: `forward_=get_forward`
- input: `reverse_=get_reverse`
- output: `forward_=READS / "{sample}.{library}_1.fq.gz"`
- output: `reverse_=READS / "{sample}.{library}_2.fq.gz"`
- log: `READS / "{sample}.{library}.log"`
- benchmark: `READS / "benchmark/{sample}.{library}.tsv"`
- container: `reads` (see `config/.docker.yml`)
- escalation: default

**`reads__link`**

Symlink every sample/library's raw reads listed in samples.tsv

Target rule: it runs nothing itself and only asks for these files.

- input: `[READS / f"{sample}.{library}_{end}.fq.gz" for sample, library in SAMPLE_LIBRARY for end in (1, 2)]`

## Module `reference`

### `reference/__main__.smk`

**`reference`**

Stage and recompress the reference host genomes

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.reference__hosts.input`
- input: `PIPELINE_REPORT / "reference.pdf"`

### `reference/hosts.smk`

**`reference__hosts__recompress`**

Recompress one host genome with bgzip, which samtools faidx needs

- input: `lambda wildcards: features["hosts"][wildcards.genome]`
- output: `HOST_FASTA`
- log: `HOST_GENOMES / "{genome}.log"`
- benchmark: `HOST_GENOMES / "benchmark/{genome}.tsv"`
- container: `reference` (see `config/.docker.yml`)
- escalation: small

**`reference__hosts`**

Aggregate the recompressed genome for every configured host

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(HOST_FASTA, genome=HOST_NAMES)`

## Module `preprocess`

### `preprocess/__main__.smk`

**`preprocess`**

Trim reads with fastp, remove host reads with bowtie2, and evaluate with fastqc/samtools

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.preprocess__bowtie2.input`
- input: `rules.preprocess__fastp.input`
- input: `rules.preprocess__samtools.input`
- input: `rules.preprocess__fastqc.input`
- input: `PIPELINE_REPORT / "preprocess.pdf"`

### `preprocess/bowtie2.smk`

**`preprocess__bowtie2__build`**

Index one host genome for read mapping

- input: `genome=HOST_FASTA`
- input: `fai=HOST_FAI`
- output: `index=touch(HOST_INDEX / "{genome}")`
- log: `HOST_INDEX / "{genome}.log"`
- benchmark: `HOST_INDEX / "benchmark/{genome}.tsv"`
- container: `bowtie2` (see `config/.docker.yml`)
- escalation: medium

**`preprocess__bowtie2__map`**

Map one library against one host genome, as one step of the decontamination chain

- input: `forward_=reads_for_host_mapping(1)`
- input: `reverse_=reads_for_host_mapping(2)`
- input: `index=HOST_INDEX / "{genome}"`
- input: `genome=HOST_FASTA`
- input: `fai=HOST_FAI`
- output: `cram=temp(HOST_CRAM)`
- output: `counts=HOST_COUNTS / "{genome}" / f"{LIBRARY}.chr_alignment_counts.tsv"`
- log: `HOST_MAPPING / "{genome}" / f"{LIBRARY}.log"`
- benchmark: `HOST_MAPPING / "benchmark/{genome}" / f"{LIBRARY}.tsv"`
- params: `sort_memory=params["preprocess"]["bowtie2"]["samtools"]["mem_per_thread"]`
- params: `rg_id=compose_rg_id`
- params: `rg_extra=compose_rg_extra`
- container: `bowtie2` (see `config/.docker.yml`)
- escalation: medium

**`preprocess__bowtie2__extract_nonhost__run`**

Write the read pairs with neither mate on this host genome to FASTQ, for the next step of the chain

- input: `cram=HOST_CRAM`
- input: `genome=HOST_FASTA`
- input: `fai=HOST_FAI`
- output: `forward_=temp(HOST_MAPPING / "non{genome}" / f"{LIBRARY}_1.fq.gz")`
- output: `reverse_=temp(HOST_MAPPING / "non{genome}" / f"{LIBRARY}_2.fq.gz")`
- log: `HOST_MAPPING / "non{genome}" / f"{LIBRARY}.log"`
- benchmark: `HOST_MAPPING / "benchmark/non{genome}" / f"{LIBRARY}.tsv"`
- params: `sort_tmpdir=lambda wc: f"./samtools_sort_tmp/{wc.sample_id}.{wc.library_id}"`
- container: `bowtie2` (see `config/.docker.yml`)
- escalation: small

**`preprocess__store_final_fastq`**

Copy the fully preprocessed reads (post-decontamination, or post-fastp if no hosts) to their final path

- input: `forward_=reads_after_last_host(1)`
- input: `reverse_=reads_after_last_host(2)`
- output: `forward_=CLEAN_FORWARD`
- output: `reverse_=CLEAN_REVERSE`
- log: `CLEAN_READS / "log" / f"{LIBRARY}.log"`
- benchmark: `CLEAN_READS / "benchmark" / f"{LIBRARY}.tsv"`
- container: `bowtie2` (see `config/.docker.yml`)
- escalation: small

**`preprocess__bowtie2__extract_nonhost`**

Store the final decontaminated FASTQs for every sample/library

Target rule: it runs nothing itself and only asks for these files.

- input: `[CLEAN_READS / f"{sample_id}.{library_id}_{end}.fq.gz" for sample_id, library_id in SAMPLE_LIBRARY for end in (1, 2)]`

**`preprocess__bowtie2`**

Run the full host-decontamination chain (index, map, extract, store) for every host

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.preprocess__bowtie2__extract_nonhost.input`

### `preprocess/fastp.smk`

**`preprocess__fastp__run`**

Run fastp on one library

- input: `forward_=READS / "{sample_id}.{library_id}_1.fq.gz"`
- input: `reverse_=READS / "{sample_id}.{library_id}_2.fq.gz"`
- output: `forward_=FASTP / "{sample_id}.{library_id}_1.fq.gz"`
- output: `reverse_=FASTP / "{sample_id}.{library_id}_2.fq.gz"`
- output: `unpaired1=FASTP / "{sample_id}.{library_id}_u1.fq.gz"`
- output: `unpaired2=FASTP / "{sample_id}.{library_id}_u2.fq.gz"`
- output: `html=FASTP / "{sample_id}.{library_id}_fastp.html"`
- output: `json=FASTP / "{sample_id}.{library_id}_fastp.json"`
- log: `FASTP / "{sample_id}.{library_id}.log"`
- benchmark: `FASTP / "benchmark/{sample_id}.{library_id}.tsv"`
- params: `adapter_forward=get_forward_adapter`
- params: `adapter_reverse=get_reverse_adapter`
- params: `extra=params["preprocess"]["fastp"]["extra"]`
- params: `length_required=params["preprocess"]["fastp"]["length_required"]`
- params: `work_prefix=lambda w: FASTP / f"{w.sample_id}.{w.library_id}_tmp"`
- container: `preprocess` (see `config/.docker.yml`)
- escalation: medium

**`preprocess__fastp`**

Aggregate all fastp outputs

Target rule: it runs nothing itself and only asks for these files.

- input: `reads=[FASTP / f"{sample_id}.{library_id}_{end}.fq.gz" for sample_id, library_id in SAMPLE_LIBRARY for end in "1 2 u1 u2".split()]`
- input: `json=[FASTP / f"{sample_id}.{library_id}_fastp.json" for sample_id, library_id in SAMPLE_LIBRARY]`

### `preprocess/fastqc.smk`

**`preprocess__fastqc__fastp`**

FastQC reports for the fastp-trimmed reads

Target rule: it runs nothing itself and only asks for these files.

- input: `[FASTP / f"{sample_id}.{library_id}_{end}_fastqc.{ext}" for sample_id, library_id in SAMPLE_LIBRARY for end in (1, 2) for ext in ("html", "zip")]`

**`preprocess__fastqc__nonhost`**

FastQC reports for the reads left over after each host-decontamination step

Target rule: it runs nothing itself and only asks for these files.

- input: `[HOST_MAPPING / f"non{genome}" / f"{sample_id}.{library_id}_{end}_fastqc.{ext}" for genome in HOST_NAMES for sample_id, library_id in SAMPLE_LIBRARY for end in (1, 2) for ext in ("html", "zip")]`

**`preprocess__fastqc`**

Aggregate every FastQC report produced during preprocessing

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.preprocess__fastqc__fastp.input`
- input: `rules.preprocess__fastqc__nonhost.input`

### `preprocess/samtools.smk`

**`preprocess__samtools__stats_cram`**

Mapping statistics of one library on one host genome with samtools stats

- input: `cram=HOST_CRAM`
- input: `crai=HOST_CRAI`
- input: `genome=HOST_FASTA`
- input: `fai=HOST_FAI`
- output: `HOST_MAPPING / "{genome}" / f"{LIBRARY}.stats.txt"`
- log: `HOST_MAPPING / "{genome}" / f"{LIBRARY}.stats.log"`
- benchmark: `HOST_MAPPING / "benchmark/{genome}" / f"{LIBRARY}.stats.tsv"`
- container: `preprocess` (see `config/.docker.yml`)
- escalation: small

**`preprocess__samtools`**

Collect samtools stats/flagstats for every host-mapping CRAM

Target rule: it runs nothing itself and only asks for these files.

- input: `[HOST_MAPPING / genome / f"{sample_id}.{library_id}.{ext}" for genome in HOST_NAMES for sample_id, library_id in SAMPLE_LIBRARY for ext in ("stats.txt", "flagstats.txt")]`

## Module `read_annotate`

### `read_annotate/__main__.smk`

**`read_annotate`**

Run the read-based annotation tools

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.read_annotate__diamond.input`
- input: `rules.read_annotate__kraken2.input`
- input: `rules.read_annotate__krona.input`
- input: `rules.read_annotate__humann.input`
- input: `rules.read_annotate__metaphlan.input`
- input: `rules.read_annotate__nonpareil.input`
- input: `rules.read_annotate__phyloflash.input`
- input: `rules.read_annotate__singlem.input`
- input: `rules.read_annotate__sylph.input`
- input: `PIPELINE_REPORT / "read_annotate.pdf"`

**`read_annotate_extra`**

Run the read-based annotation tools

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.read_annotate__ncyc.input`

### `read_annotate/diamond.smk`

**`read_annotate__diamond__assign`**

Run Diamond with SHM/NVME staging if possible.

- input: `forwards=CLEAN_FORWARD`
- input: `reverses=CLEAN_REVERSE`
- input: `database=lambda w: features["databases"]["diamond"][w.diamond_db]`
- output: `out_R1=DIAMOND / "{diamond_db}" / "{sample_id}.{library_id}_R1.out"`
- output: `out_R2=DIAMOND / "{diamond_db}" / "{sample_id}.{library_id}_R2.out"`
- log: `DIAMOND / "{diamond_db}_{sample_id}_{library_id}.log"`
- benchmark: `DIAMOND / "benchmark/{diamond_db}_{sample_id}_{library_id}.tsv"`
- params: `max_target_seqs=params["read_annotate"]["diamond"]["max-target-seqs"]`
- params: `max_attempt=len(get_escalation_order("read_annotate__diamond__assign"))`
- params: `in_folder=FASTP`
- params: `out_folder=lambda w: DIAMOND / w.diamond_db`
- params: `run_in_shm=config["diamond_shm"]`
- params: `copy_dbs=config["copy_dbs"]`
- params: `diamond_shm=DIAMONDSHM`
- params: `diamond_nvme=DIAMONDNVME`
- params: `diamond_db_shm=lambda w: os.path.join(DIAMONDSHM, w.diamond_db)`
- params: `diamond_path=lambda w: os.path.basename(features["databases"]["diamond"][w.diamond_db])`
- params: `diamond_db_nvme=lambda w: os.path.join(DIAMONDNVME, w.diamond_db)`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: medium_nvme

**`read_annotate__diamond__summarise`**

Run R script to summarise Diamond results

- input: `lambda w: [DIAMOND / w.diamond_db / f"{sample_id}.{library_id}_R1.out" for sample_id, library_id in SAMPLE_LIBRARY] + [DIAMOND / w.diamond_db / f"{sample_id}.{library_id}_R2.out" for sample_id, library_id in SAMPLE_LIBRARY]`
- output: `DIAMOND / "{diamond_db}" / "summary_a.tsv"`
- output: `DIAMOND / "{diamond_db}" / "summary_b.tsv"`
- log: `DIAMOND / "{diamond_db}" / "read_annotate__diamond__summarise.log"`
- benchmark: `DIAMOND / "{diamond_db}" / "benchmark_summarise.tsv"`
- params: `script=lambda w: config["pipeline_folder"] + "workflow/scripts/downstream_scripts/create_featuretable_diamond_" + w.diamond_db + ".R"`
- params: `project_folder=WD`
- params: `database=lambda w: w.diamond_db`
- params: `max_target_seqs=params["read_annotate"]["diamond"]["max-target-seqs"]`
- container: `r_report` (see `config/.docker.yml`)
- escalation: small

**`read_annotate__diamond`**

Run all Diamond steps

Target rule: it runs nothing itself and only asks for these files.

- input: `[DIAMOND / diamond_db / f"{sample_id}.{library_id}_R1.out" for sample_id, library_id in SAMPLE_LIBRARY for diamond_db in features["databases"]["diamond"]] + [DIAMOND / diamond_db / f"{sample_id}.{library_id}_R2.out" for sample_id, library_id in SAMPLE_LIBRARY for diamond_db in features["databases"]["diamond"]] + [DIAMOND / diamond_db / "summary_a.tsv" for diamond_db in features["databases"]["diamond"]] + [DIAMOND / diamond_db / "summary_b.tsv" for diamond_db in features["databases"]["diamond"]]`

### `read_annotate/humann.smk`

**`read_annotate__humann__run`**

Run HumanN3 over one sample

- input: `forward_=CLEAN_FORWARD`
- input: `reverse_=CLEAN_REVERSE`
- input: `prot_dbs=features["databases"]["humann_prot_dbs"]`
- input: `nt_dbs=features["databases"]["humann_nt_dbs"]`
- input: `mp_out=METAPHLAN / "profiled" / "{sample_id}.{library_id}.txt"`
- output: `humann_out=HUMANN / "{sample_id}.{library_id}_genefamilies.tsv"`
- output: `cat=temp(HUMANN / "{sample_id}.{library_id}_concatenated.fastq.gz")`
- log: `HUMANN / "log" / "{sample_id}.{library_id}.log"`
- benchmark: `HUMANN / "benchmark" / "{sample_id}.{library_id}.tsv"`
- params: `out_folder=HUMANN`
- params: `out_name="{sample_id}.{library_id}"`
- params: `additional_options=params["read_annotate"]["humann"]["additional_options"]`
- container: `humann` (see `config/.docker.yml`)
- escalation: medium

**`read_annotate__humann__condense`**

Aggregate all the HumanN results into a single table

- input: `genefamily_data=[HUMANN / f"{sample_id}.{library_id}_genefamilies.tsv" for sample_id, library_id in SAMPLE_LIBRARY]`
- output: `HUMANN / "humann_genefamilies.tsv"`
- log: `HUMANN / "humann.log"`
- benchmark: `HUMANN / "benchmark/humann.tsv"`
- params: `input_dir=HUMANN`
- container: `humann` (see `config/.docker.yml`)
- escalation: small

**`read_annotate__humann`**

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.read_annotate__humann__condense.output`

### `read_annotate/kraken2.smk`

**`read_annotate__kraken2__assign`**

Classify every sample against one kraken2 database in a single job kraken2 has no way to keep the database resident across multiple single-sample invocations, so it's staged once onto fast local storage (/dev/shm, falling back to NVMe, falling back to running in place on the final retry) and every sample is classified against that one copy. NOTE: if the job is killed, a staged copy may be left behind in /dev/shm.

- input: `forwards=[FASTP / f"{sample_id}.{library_id}_1.fq.gz" for sample_id, library_id in SAMPLE_LIBRARY]`
- input: `reverses=[FASTP / f"{sample_id}.{library_id}_2.fq.gz" for sample_id, library_id in SAMPLE_LIBRARY]`
- input: `database=lambda w: features["databases"]["kraken2"][w.kraken_db]`
- output: `out_gzs=[KRAKEN2 / "{kraken_db}" / f"{sample_id}.{library_id}.out.gz" for sample_id, library_id in SAMPLE_LIBRARY]`
- output: `reports=[KRAKEN2 / "{kraken_db}" / f"{sample_id}.{library_id}.report" for sample_id, library_id in SAMPLE_LIBRARY]`
- log: `KRAKEN2 / "{kraken_db}.log"`
- benchmark: `KRAKEN2 / "benchmark/{kraken_db}.tsv"`
- params: `max_attempt=len(get_escalation_order("read_annotate__kraken2__assign"))`
- params: `nvme=esc_val("nvme", "read_annotate__kraken2__assign")`
- params: `in_folder=FASTP`
- params: `out_folder=lambda w: KRAKEN2 / w.kraken_db`
- params: `run_in_shm=config["kraken2_shm"]`
- params: `copy_dbs=config["copy_dbs"]`
- params: `shm_dir=KRAKEN2SHM`
- params: `nvme_dir=KRAKEN2NVME`
- params: `db_shm=lambda w: os.path.join(KRAKEN2SHM, w.kraken_db)`
- params: `db_nvme=lambda w: os.path.join(KRAKEN2NVME, w.kraken_db)`
- container: `preprocess` (see `config/.docker.yml`)
- escalation: full_node

**`read_annotate__kraken2`**

Aggregate kraken2 reports for every sample against every configured database

Target rule: it runs nothing itself and only asks for these files.

- input: `[KRAKEN2 / kraken_db / f"{sample_id}.{library_id}.report" for sample_id, library_id in SAMPLE_LIBRARY for kraken_db in features["databases"]["kraken2"]]`

### `read_annotate/krona.smk`

**`read_annotate__krona__visualize`**

Create Krona plots for Kraken2 output.

- input: `KRAKEN2 / "{kraken_db}" / "{sample_id}.{library_id}.report"`
- output: `KRONA / "{kraken_db}" / "{sample_id}.{library_id}.html"`
- log: `KRONA / "{kraken_db}_{sample_id}.{library_id}.log"`
- benchmark: `KRONA / "benchmark/{kraken_db}_{sample_id}.{library_id}bsk.tsv"`
- params: `krona_db=features["databases"]["krona"]`
- container: `krona` (see `config/.docker.yml`)
- escalation: medium

**`read_annotate__krona`**

Run krona for the kraken output

Target rule: it runs nothing itself and only asks for these files.

- input: `[KRONA / kraken_db / f"{sample_id}.{library_id}.html" for sample_id, library_id in SAMPLE_LIBRARY for kraken_db in features["databases"]["kraken2"]]`

### `read_annotate/metaphlan.smk`

**`read_annotate__metaphlan__run`**

Run metaphlan over one sample

- input: `forward_=CLEAN_FORWARD`
- input: `reverse_=CLEAN_REVERSE`
- input: `data=features["databases"]["metaphlan4"]`
- output: `bt2_out=METAPHLAN / "bowtie2_out" / "{sample_id}.{library_id}.bz2"`
- output: `mp_out=METAPHLAN / "profiled" / "{sample_id}.{library_id}.txt"`
- log: `METAPHLAN / "log" / "{sample_id}.{library_id}.log"`
- benchmark: `METAPHLAN / "benchmark" / "{sample_id}.{library_id}.tsv"`
- params: `tmp=config["tmp_storage"]`
- container: `preprocess` (see `config/.docker.yml`)
- escalation: medium

**`read_annotate__metaphlan__condense`**

Aggregate all the metaphlan results into a single table

- input: `profiled_data=[METAPHLAN / "profiled" / f"{sample_id}.{library_id}.txt" for sample_id, library_id in SAMPLE_LIBRARY]`
- output: `METAPHLAN / "metaphlan_profiled.tsv"`
- log: `METAPHLAN / "metaphlan.log"`
- benchmark: `METAPHLAN / "benchmark/metaphlan.tsv"`
- params: `input_dir=METAPHLAN`
- container: `preprocess` (see `config/.docker.yml`)
- escalation: small

**`read_annotate__metaphlan`**

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.read_annotate__metaphlan__condense.output`

### `read_annotate/ncyc.smk`

**`read_annotate__ncyc__prepare_input`**

Create sample sheet for NCycDB Perl wrapper (runs all samples at once)

- input: `forwards=[CLEAN_READS / f"{sample_id}.{library_id}_1.fq.gz" for sample_id, library_id in SAMPLE_LIBRARY]`
- input: `reverses=[CLEAN_READS / f"{sample_id}.{library_id}_2.fq.gz" for sample_id, library_id in SAMPLE_LIBRARY]`
- output: `NCYC / "ncyc_samples.tsv"`
- log: `NCYC / "log" / "ncyc_samples.log"`
- benchmark: `NCYC / "benchmark" / "ncyc_samples.tsv"`
- params: `folder=config["pipeline_folder"]`
- params: `reads=CLEAN_READS`
- params: `outdir=NCYC / "results"`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: small

**`read_annotate__ncyc__run`**

Run NCycDB Perl wrapper on all samples

- input: `NCYC / "ncyc_samples.tsv"`
- output: `NCYC / "ncyc_results.tsv"`
- log: `NCYC / "log" / "ncyc_run.log"`
- benchmark: `NCYC / "benchmark" / "ncyc_run.tsv"`
- params: `folder=config["pipeline_folder"]`
- params: `outdir=NCYC`
- params: `reads_dir=CLEAN_READS`
- params: `faa=features["databases"]["ncyc"]`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: medium

**`read_annotate__ncyc`**

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.read_annotate__ncyc__run.output`

### `read_annotate/nonpareil.smk`

**`read_annotate__nonpareil__run`**

Estimate sequence coverage/diversity for one sample with Nonpareil Nonpareil only takes one read of the pair, and needs a real (decompressed) FASTQ file on disk -- it doesn't accept a process-substitution pipe. On low-coverage samples it can legitimately fail to converge, in which case it produces empty output files rather than erroring; the `touch()` wrappers below make sure Snakemake still sees the expected outputs.

- input: `forward_=CLEAN_FORWARD`
- output: `touch(NONPAREIL / f"{LIBRARY}.npa")`
- output: `touch(NONPAREIL / f"{LIBRARY}.npc")`
- output: `touch(NONPAREIL / f"{LIBRARY}.npl")`
- output: `touch(NONPAREIL / f"{LIBRARY}.npo")`
- log: `NONPAREIL / f"{LIBRARY}.log"`
- benchmark: `NONPAREIL / f"benchmark/{LIBRARY}.tsv"`
- params: `X=params["read_annotate"]["nonpareil"]["X"]`
- params: `tmp=config["tmp_storage"]`
- container: `preprocess` (see `config/.docker.yml`)
- escalation: medium

**`read_annotate__nonpareil__aggregate`**

Aggregate all the nonpareil results into a single table

- input: `[f"{NONPAREIL}/{sample_id}.{library_id}.npo" for sample_id, library_id in SAMPLE_LIBRARY]`
- output: `NONPAREIL / "nonpareil.tsv"`
- log: `NONPAREIL / "nonpareil.log"`
- benchmark: `NONPAREIL / "benchmark/nonpareil.tsv"`
- params: `input_dir=NONPAREIL`
- params: `script_folder=SCRIPT_FOLDER`
- container: `preprocess` (see `config/.docker.yml`)
- escalation: small

**`read_annotate__nonpareil`**

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.read_annotate__nonpareil__aggregate.output`

### `read_annotate/phyloflash.smk`

**`read_annotate__phyloflash__run`**

Run PhyloFlash over one sample

- input: `forward_=CLEAN_FORWARD`
- input: `reverse_=CLEAN_REVERSE`
- input: `phyloflash_dbs=PHYLOFLASH_DBS`
- output: `phyloflash_out=PHYLOFLASH / "{sample_id}_{library_id}.phyloFlash.html"`
- output: `phyloflash_log=PHYLOFLASH / "{sample_id}_{library_id}.phyloFlash.log"`
- log: `PHYLOFLASH / "log" / "{sample_id}.{library_id}.log"`
- benchmark: `PHYLOFLASH / "benchmark" / "{sample_id}.{library_id}.tsv"`
- params: `lib="{sample_id}_{library_id}"`
- params: `outdir=PHYLOFLASH`
- container: `phyloflash` (see `config/.docker.yml`)
- escalation: medium_nvme

**`read_annotate__phyloflash__condense`**

Aggregate all the PhyloFlash results into a single table

- input: `phyloflash_logs=[PHYLOFLASH / f"{sample_id}_{library_id}.phyloFlash.log" for sample_id, library_id in SAMPLE_LIBRARY]`
- output: `PHYLOFLASH / "phyloflash_all.log"`
- log: `PHYLOFLASH / "phyloflash.log"`
- benchmark: `PHYLOFLASH / "benchmark/phyloflash.tsv"`
- params: `input_dir=PHYLOFLASH`
- container: `phyloflash` (see `config/.docker.yml`)
- escalation: small

**`read_annotate__phyloflash`**

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.read_annotate__phyloflash__condense.output`

### `read_annotate/singlem.smk`

**`read_annotate__singlem__pipe`**

Profile marker-gene taxonomy for one sample with SingleM SingleM's own docs recommend raw reads, but this pipeline feeds it the decontaminated, quality-trimmed reads instead, consistent with every other read-based annotation tool here.

- input: `forward_=CLEAN_FORWARD`
- input: `reverse_=CLEAN_REVERSE`
- input: `data=features["databases"]["singlem"]`
- output: `archive_otu_table=SINGLEM / "pipe" / "{sample_id}.{library_id}.archive.json"`
- output: `otu_table=SINGLEM / "pipe" / "{sample_id}.{library_id}.otu_table.tsv"`
- output: `condense=SINGLEM / "pipe" / "{sample_id}.{library_id}.condense.tsv"`
- log: `SINGLEM / "pipe" / "{sample_id}.{library_id}.log"`
- benchmark: `SINGLEM / "benchmark/pipe" / "{sample_id}.{library_id}.tsv"`
- params: `tmp=config["tmp_storage"]`
- container: `preprocess` (see `config/.docker.yml`)
- escalation: medium_nvme

**`read_annotate__singlem__condense`**

Aggregate all the singlem results into a single table

- input: `archive_otu_tables=[SINGLEM / "pipe" / f"{sample_id}.{library_id}.archive.json" for sample_id, library_id in SAMPLE_LIBRARY]`
- input: `database=features["databases"]["singlem"]`
- output: `condense=SINGLEM / "singlem.tsv"`
- log: `SINGLEM / "singlem.log"`
- benchmark: `SINGLEM / "benchmark/singlem.tsv"`
- params: `input_dir=SINGLEM`
- container: `preprocess` (see `config/.docker.yml`)
- escalation: small

**`read_annotate__singlem__microbial_fraction`**

Run singlem microbial_fraction over one sample

- input: `forward_=CLEAN_FORWARD`
- input: `reverse_=CLEAN_REVERSE`
- input: `data=features["databases"]["singlem"]`
- input: `condense=SINGLEM / "pipe" / "{sample_id}.{library_id}.condense.tsv"`
- output: `microbial_fraction=SINGLEM / "microbial_fraction" / "{sample_id}.{library_id}.tsv"`
- log: `SINGLEM / "microbial_fraction" / "{sample_id}.{library_id}.log"`
- benchmark: `SINGLEM / "benchmark/microbial_fraction" / "{sample_id}.{library_id}.tsv"`
- container: `preprocess` (see `config/.docker.yml`)
- escalation: small

**`read_annotate__singlem__aggregate_microbial_fraction`**

Aggregate all the microbial_fraction files into one tsv

- input: `tsvs=[SINGLEM / "microbial_fraction" / f"{sample_id}.{library_id}.tsv" for sample_id, library_id in SAMPLE_LIBRARY]`
- output: `tsv=SINGLEM / "microbial_fraction.tsv"`
- log: `SINGLEM / "microbial_fraction.log"`
- benchmark: `SINGLEM / "benchmark/microbial_fraction.tsv"`
- container: `preprocess` (see `config/.docker.yml`)
- escalation: small

**`read_annotate__singlem`**

Aggregate the SingleM taxonomic profile and microbial-fraction results

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.read_annotate__singlem__condense.output`
- input: `rules.read_annotate__singlem__aggregate_microbial_fraction.output`

### `read_annotate/sylph.smk`

**`read_annotate__sylph_profile`**

Run Sylph profiler

- input: `forwards=CLEAN_FORWARD`
- input: `reverses=CLEAN_REVERSE`
- input: `db=features["databases"]["sylph"]`
- output: `PRE_SYLPH / "{sample_id}.{library_id}.profiling.tsv"`
- log: `PRE_SYLPH / "{sample_id}.{library_id}.profiling_report.log"`
- benchmark: `PRE_SYLPH / "benchmark/{sample_id}.{library_id}.tsv"`
- container: `sylph` (see `config/.docker.yml`)
- escalation: medium_nvme

**`read_annotate__sylph`**

Run Sylph

Target rule: it runs nothing itself and only asks for these files.

- input: `[PRE_SYLPH / f"{sample_id}.{library_id}.profiling.tsv" for sample_id, library_id in SAMPLE_LIBRARY]`

## Module `assemble`

### `assemble/__main__.smk`

**`assemble`**

Assemble, bin (CONCOCT/MaxBin2/MetaBAT2), combine bins with MAGScoT and dereplicate with dRep

Target rule: it runs nothing itself and only asks for these files.

- input: `MAG_CATALOGUE`
- input: `PIPELINE_REPORT / "assemble.pdf"`

### `assemble/binners/concoct.smk`

**`assemble__concoct__run`**

Bin the contigs of one assembly with CONCOCT, following the steps of its manual

- input: `contigs=CONTIGS`
- input: `alignments=assembly_alignments`
- output: `directory(CONCOCT / "{assembly_id}")`
- log: `CONCOCT / "{assembly_id}.log"`
- benchmark: `CONCOCT / "benchmark/{assembly_id}.tsv"`
- container: `concoct` (see `config/.docker.yml`)
- escalation: large

**`assemble__concoct`**

Run CONCOCT for every assembly

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(CONCOCT / "{assembly_id}", assembly_id=ASSEMBLIES)`

### `assemble/binners/maxbin2.smk`

**`assemble__maxbin2__run`**

Bin the contigs of one assembly with MaxBin2, using one abundance value per contig

- input: `contigs=CONTIGS`
- input: `alignments=assembly_alignments`
- output: `directory(MAXBIN2 / "{assembly_id}")`
- log: `MAXBIN2 / "{assembly_id}.log"`
- benchmark: `MAXBIN2 / "benchmark/{assembly_id}.tsv"`
- params: `min_contig=params["assemble"]["maxbin"]["min_contig_len"]`
- container: `assemble` (see `config/.docker.yml`)
- escalation: large

**`assemble__maxbin2`**

Run MaxBin2 for every assembly

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(MAXBIN2 / "{assembly_id}", assembly_id=ASSEMBLIES)`

### `assemble/binners/metabat2.smk`

**`assemble__metabat2__run`**

Bin the contigs of one assembly with MetaBAT2, using each contig's depth in each library

- input: `contigs=CONTIGS`
- input: `alignments=assembly_alignments`
- input: `indexes=assembly_alignment_indexes`
- output: `directory(METABAT2 / "{assembly_id}")`
- log: `METABAT2 / "{assembly_id}.log"`
- benchmark: `METABAT2 / "benchmark/{assembly_id}.tsv"`
- params: `min_contig=params["assemble"]["metabat"]["min_contig_len"]`
- container: `assemble` (see `config/.docker.yml`)
- escalation: large

**`assemble__metabat2`**

Run MetaBAT2 for every assembly

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(METABAT2 / "{assembly_id}", assembly_id=ASSEMBLIES)`

### `assemble/bowtie2.smk`

**`assemble__bowtie2__build__run`**

Index the contigs of one assembly for read mapping

- input: `CONTIGS`
- output: `index=touch(ASSEMBLY_INDEX / "{assembly_id}")`
- log: `ASSEMBLY_INDEX / "{assembly_id}.log"`
- benchmark: `ASSEMBLY_INDEX / "benchmark/{assembly_id}.tsv"`
- container: `assemble` (see `config/.docker.yml`)
- escalation: medium

**`assemble__bowtie2__build`**

Index every assembly

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(ASSEMBLY_INDEX / "{assembly_id}", assembly_id=ASSEMBLIES)`

**`assemble__bowtie2__map`**

Map one library against one assembly and sort it into the configured format

- input: `index=ASSEMBLY_INDEX / "{assembly_id}"`
- input: `contigs=CONTIGS`
- input: `forward_=CLEAN_FORWARD`
- input: `reverse_=CLEAN_REVERSE`
- output: `alignment=ASSEMBLY_MAPPING / f"{_LIBRARY_ON_ASSEMBLY}.{ALIGN_EXT}"`
- output: `unsorted=temp(ASSEMBLY_MAPPING / f"{_LIBRARY_ON_ASSEMBLY}.tmp.bam")`
- log: `ASSEMBLY_MAPPING / f"{_LIBRARY_ON_ASSEMBLY}.log"`
- benchmark: `ASSEMBLY_MAPPING / f"benchmark/{_LIBRARY_ON_ASSEMBLY}.tsv"`
- params: `sort_memory=params["assemble"]["samtools"]["mem"]`
- params: `rg_id=compose_rg_id`
- params: `rg_extra=compose_rg_extra`
- container: `assemble` (see `config/.docker.yml`)
- escalation: medium

**`assemble__bowtie2`**

Map every library against every assembly it belongs to

Target rule: it runs nothing itself and only asks for these files.

- input: `[ASSEMBLY_MAPPING / f"{assembly_id}.{sample_id}.{library_id}.{ALIGN_EXT}" for assembly_id, sample_id, library_id in ASSEMBLY_LIBRARIES]`

### `assemble/drep.smk`

**`assemble__drep__split_bins`**

Write every refined bin of all assemblies to its own FASTA, the way dRep takes its genomes

- input: `expand(MAGSCOT / "{assembly_id}.fa.gz", assembly_id=ASSEMBLIES)`
- output: `directory(_BIN_FILES)`
- log: `DREP / "separate_bins.log"`
- benchmark: `DREP / "benchmark/separate_bins.tsv"`
- params: `script_folder=SCRIPT_FOLDER`
- container: `assemble` (see `config/.docker.yml`)
- escalation: small

**`assemble__drep__run`**

Dereplicate the bins of all assemblies into one set of genomes with dRep

- input: `_BIN_FILES`
- output: `genomes=directory(MAG_GENOMES)`
- output: `archives=expand(DREP / "{section}.tar.gz", section=("data", "data_tables"))`
- log: `DREP / "drep.log"`
- benchmark: `DREP / "benchmark/drep_run.tsv"`
- params: `settings=params["assemble"]["drep"]`
- container: `assemble` (see `config/.docker.yml`)
- escalation: medium_nvme

**`assemble__drep__catalogue`**

Concatenate the dereplicated genomes into the MAG catalogue

- input: `MAG_GENOMES`
- output: `MAG_CATALOGUE`
- log: `DREP / "dereplicated_genomes.log"`
- benchmark: `DREP / "benchmark/join_genomes.tsv"`
- container: `assemble` (see `config/.docker.yml`)
- escalation: medium_nvme

**`assemble__drep`**

Build the MAG catalogue from the bins of all assemblies

Target rule: it runs nothing itself and only asks for these files.

- input: `MAG_CATALOGUE`

### `assemble/magscot.smk`

**`assemble__magscot__prodigal`**

Predict the proteins of one assembly, with one prodigal per FASTA chunk

- input: `CONTIGS`
- output: `_MAGSCOT_RUN / "prodigal.faa"`
- log: `_MAGSCOT_RUN / "prodigal.log"`
- benchmark: `_MAGSCOT_RUN / "benchmark_prodigal.tsv"`
- container: `assemble` (see `config/.docker.yml`)
- escalation: medium_nvme

**`assemble__magscot__hmmsearch`**

Search the proteins of one assembly against one marker gene set of MAGScoT (Pfam or TIGRFAM)

- input: `proteins=_MAGSCOT_RUN / "prodigal.faa"`
- input: `hmm=lambda wildcards: features["magscot"][f"{wildcards.marker_set}_hmm"]`
- output: `hits=_MAGSCOT_RUN / "{marker_set}.tblout.gz"`
- log: `_MAGSCOT_RUN / "{marker_set}.log"`
- benchmark: `_MAGSCOT_RUN / "benchmark_hmmsearch_{marker_set}.tsv"`
- container: `assemble` (see `config/.docker.yml`)
- escalation: medium

**`assemble__magscot__marker_table`**

Write the marker gene hits in MAGScoT's format: protein, marker, e-value

- input: `tigr=_MAGSCOT_RUN / "tigr.tblout.gz"`
- input: `pfam=_MAGSCOT_RUN / "pfam.tblout.gz"`
- output: `_MAGSCOT_RUN / "hmm.tblout"`
- log: `_MAGSCOT_RUN / "hmm.log"`
- benchmark: `_MAGSCOT_RUN / "benchmark_join_hmms.tsv"`
- container: `assemble` (see `config/.docker.yml`)
- escalation: small

**`assemble__magscot__merge_contig_to_bin`**

List the contigs of every bin of the three binners: bin, contig, binner

- input: `concoct=CONCOCT / "{assembly_id}"`
- input: `maxbin2=MAXBIN2 / "{assembly_id}"`
- input: `metabat2=METABAT2 / "{assembly_id}"`
- output: `_MAGSCOT_RUN / "contigs_to_bin.tsv"`
- log: `_MAGSCOT_RUN / "contigs_to_bin.log"`
- benchmark: `_MAGSCOT_RUN / "benchmark_merge_contig_to_bin.tsv"`
- container: `assemble` (see `config/.docker.yml`)
- escalation: small

**`assemble__magscot__run`**

Score and refine the bins of one assembly with MAGScoT A poor assembly can leave MAGScoT without any viable bin, which it reports by failing. That is no reason to stop the pipeline, so the rule carries on with empty tables in that case.

- input: `contigs_to_bin=_MAGSCOT_RUN / "contigs_to_bin.tsv"`
- input: `markers=_MAGSCOT_RUN / "hmm.tblout"`
- output: `_MAGSCOT_RUN / "magscot.gtdb_rel207_ar53.out"`
- output: `_MAGSCOT_RUN / "magscot.gtdb_rel207_bac120.out"`
- output: `_MAGSCOT_RUN / "magscot.refined.contig_to_bin.out"`
- output: `_MAGSCOT_RUN / "magscot.refined.out"`
- output: `_MAGSCOT_RUN / "magscot.scores.out"`
- log: `_MAGSCOT_RUN / "magscot.log"`
- benchmark: `_MAGSCOT_RUN / "benchmark_run.tsv"`
- params: `prefix=lambda w: MAGSCOT / w.assembly_id / "magscot"`
- params: `settings=params["assemble"]["magscot"]`
- params: `script_folder=SCRIPT_FOLDER`
- container: `assemble` (see `config/.docker.yml`)
- escalation: small

**`assemble__magscot__label_contigs`**

Write the refined bin into the contig ids, keeping only the contigs that are in a bin

- input: `contigs=CONTIGS`
- input: `refined=_MAGSCOT_RUN / "magscot.refined.contig_to_bin.out"`
- output: `table=_MAGSCOT_RUN / "magscot.reformat.tsv"`
- output: `binned_contigs=MAGSCOT / "{assembly_id}.fa.gz"`
- log: `_MAGSCOT_RUN / "magscot.rename.log"`
- benchmark: `_MAGSCOT_RUN / "benchmark_rename.tsv"`
- params: `script_folder=SCRIPT_FOLDER`
- container: `assemble` (see `config/.docker.yml`)
- escalation: small

**`assemble__magscot`**

Run MAGScoT for every assembly

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(MAGSCOT / "{assembly_id}.fa.gz", assembly_id=ASSEMBLIES)`

### `assemble/megahit.smk`

**`assemble__megahit__run`**

Assemble the libraries of one assembly_id with MEGAHIT and give the contigs pipeline ids --force because Snakemake has already created the output folder, which MEGAHIT otherwise refuses to write into.

- input: `forwards=assembly_reads(1)`
- input: `reverses=assembly_reads(2)`
- output: `contigs=MEGAHIT / "{assembly_id}.fa.gz"`
- output: `workdir_archive=MEGAHIT / "{assembly_id}.tar.gz"`
- log: `MEGAHIT / "{assembly_id}.log"`
- benchmark: `MEGAHIT / "benchmark/{assembly_id}.tsv"`
- params: `workdir=lambda w: MEGAHIT / w.assembly_id`
- params: `forwards=assembly_reads(1, separator=",")`
- params: `reverses=assembly_reads(2, separator=",")`
- params: `settings=params["assemble"]["megahit"]`
- params: `script_folder=SCRIPT_FOLDER`
- container: `assemble` (see `config/.docker.yml`)
- escalation: large

**`assemble__megahit`**

Run MEGAHIT for every assembly

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(MEGAHIT / "{assembly_id}.fa.gz", assembly_id=ASSEMBLIES)`

### `assemble/metaspades.smk`

**`assemble__metaspades__run`**

Assemble the pooled libraries of one assembly_id with metaSPAdes and give the contigs pipeline ids metaSPAdes takes a single library per run in meta mode, hence the pooling. The eukaryote module reads the assembly graph back from the archive of the working folder.

- input: `forwards=assembly_reads(1)`
- input: `reverses=assembly_reads(2)`
- output: `contigs=METASPADES / "{assembly_id}.fa.gz"`
- output: `workdir_archive=METASPADES / "{assembly_id}.tar.gz"`
- output: `pooled_forward=temp(METASPADES / "{assembly_id}_R1_concat.fastq.gz")`
- output: `pooled_reverse=temp(METASPADES / "{assembly_id}_R2_concat.fastq.gz")`
- log: `METASPADES / "{assembly_id}.log"`
- benchmark: `METASPADES / "benchmark/{assembly_id}.tsv"`
- params: `workdir=lambda w: METASPADES / w.assembly_id`
- params: `settings=params["assemble"]["metaspades"]`
- params: `script_folder=SCRIPT_FOLDER`
- container: `assemble` (see `config/.docker.yml`)
- escalation: large

**`assemble__metaspades`**

Run metaSPAdes for every assembly

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(METASPADES / "{assembly_id}.fa.gz", assembly_id=ASSEMBLIES)`

## Module `quantify`

### `quantify/__main__.smk`

**`quantify`**

Map reads against the assemblies and quantify coverage with CoverM

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.quantify__coverm.input`
- input: `rules.quantify__samtools.input`
- input: `PIPELINE_REPORT / "quantify.pdf"`

### `quantify/bowtie2.smk`

**`quantify__bowtie2__build`**

Index the MAG catalogue for read mapping

- input: `MAG_CATALOGUE`
- output: `index=touch(MAG_INDEX / "dereplicated_genomes")`
- log: `MAG_INDEX / "dereplicated_genomes.log"`
- benchmark: `MAG_INDEX / "benchmark/dereplicated_genomes.tsv"`
- container: `bowtie2` (see `config/.docker.yml`)
- escalation: small

**`quantify__bowtie2__map`**

Map one library against the MAG catalogue

- input: `index=MAG_INDEX / "dereplicated_genomes"`
- input: `forward_=CLEAN_FORWARD`
- input: `reverse_=CLEAN_REVERSE`
- input: `catalogue=MAG_CATALOGUE`
- input: `fai=MAG_CATALOGUE_FAI`
- output: `MAG_CRAM`
- log: `MAG_MAPPING / f"{LIBRARY}.log"`
- benchmark: `MAG_MAPPING / f"benchmark/{LIBRARY}.tsv"`
- params: `sort_memory=params["quantify"]["samtools"]["mem"]`
- params: `rg_id=compose_rg_id`
- params: `rg_extra=compose_rg_extra`
- container: `bowtie2` (see `config/.docker.yml`)
- escalation: medium

**`quantify__bowtie2`**

Map every library against the MAG catalogue

Target rule: it runs nothing itself and only asks for these files.

- input: `[MAG_MAPPING / f"{sample_id}.{library_id}.cram" for sample_id, library_id in SAMPLE_LIBRARY]`

### `quantify/coverm.smk`

**`quantify__coverm__genome__run`**

CoverM values of the MAGs in one library, for one method

- input: `alignment=MAG_CRAM`
- input: `index=MAG_CRAI`
- input: `catalogue=MAG_CATALOGUE`
- input: `fai=MAG_CATALOGUE_FAI`
- output: `COVERM / "genome" / "{method}" / f"{LIBRARY}.tsv"`
- log: `COVERM / "genome" / "{method}" / f"{LIBRARY}.log"`
- benchmark: `COVERM / "genome" / "{method}" / "benchmark" / f"{LIBRARY}.tsv"`
- params: `settings=params["quantify"]["coverm"]["genome"]`
- container: `quantify` (see `config/.docker.yml`)
- escalation: small

**`quantify__coverm__genome_aggregate`**

Join the genome-level tables of all libraries for one method

- input: `coverm_library_tables("genome")`
- output: `COVERM / "genome.{method}.tsv"`
- log: `COVERM / "genome.{method}.log"`
- benchmark: `COVERM / "benchmark_genome.{method}.tsv"`
- params: `script_folder=SCRIPT_FOLDER`
- container: `quantify` (see `config/.docker.yml`)
- escalation: small

**`quantify__coverm__genome`**

Run genome-level CoverM for every configured method

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(COVERM / "genome.{method}.tsv", method=params["quantify"]["coverm"]["genome"]["methods"])`

**`quantify__coverm__contig_one`**

CoverM values of the catalogue's contigs in one library, for one method

- input: `alignment=MAG_CRAM`
- input: `index=MAG_CRAI`
- input: `catalogue=MAG_CATALOGUE`
- input: `fai=MAG_CATALOGUE_FAI`
- output: `COVERM / "contig" / "{method}" / f"{LIBRARY}.tsv"`
- log: `COVERM / "contig" / "{method}" / f"{LIBRARY}.log"`
- benchmark: `COVERM / "contig" / "{method}" / "benchmark" / f"{LIBRARY}.tsv"`
- container: `quantify` (see `config/.docker.yml`)
- escalation: small

**`quantify__coverm__contig_aggregate`**

Join the contig-level tables of all libraries for one method

- input: `coverm_library_tables("contig")`
- output: `COVERM / "contig.{method}.tsv"`
- log: `COVERM / "contig.{method}.log"`
- benchmark: `COVERM / "benchmark_contig.{method}.tsv"`
- params: `script_folder=SCRIPT_FOLDER`
- container: `quantify` (see `config/.docker.yml`)
- escalation: small

**`quantify__coverm__contig`**

Run contig-level CoverM for every configured method

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(COVERM / "contig.{method}.tsv", method=params["quantify"]["coverm"]["contig"]["methods"])`

**`quantify__coverm`**

Aggregate contig- and genome-level CoverM results

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.quantify__coverm__contig.input`
- input: `rules.quantify__coverm__genome.input`

### `quantify/samtools.smk`

**`quantify__samtools__stats_cram`**

Mapping statistics of one library on the MAG catalogue with samtools stats

- input: `alignment=MAG_CRAM`
- input: `index=MAG_CRAI`
- input: `catalogue=MAG_CATALOGUE`
- input: `fai=MAG_CATALOGUE_FAI`
- output: `MAG_MAPPING / f"{LIBRARY}.stats.txt"`
- log: `MAG_MAPPING / f"{LIBRARY}.stats.log"`
- benchmark: `MAG_MAPPING / f"benchmark/{LIBRARY}.stats.tsv"`
- container: `quantify` (see `config/.docker.yml`)
- escalation: small

**`quantify__samtools`**

Collect samtools stats/flagstats for every MAG-mapping CRAM

Target rule: it runs nothing itself and only asks for these files.

- input: `[MAG_MAPPING / f"{sample_id}.{library_id}.{ext}" for sample_id, library_id in SAMPLE_LIBRARY for ext in ("stats.txt", "flagstats.txt")]`

## Module `mag_annotate`

### `mag_annotate/__main__.smk`

**`mag_annotate`**

Annotate the dereplicated MAG catalogue with every configured tool

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.mag_annotate__bakta.output`
- input: `rules.mag_annotate__bakta_mags.input`
- input: `rules.mag_annotate__camper.input`
- input: `rules.mag_annotate__eggnog.output`
- input: `rules.mag_annotate__quast.output`
- input: `rules.mag_annotate__checkm2__predict.output`
- input: `rules.mag_annotate__gtdbtk__classify.output`
- input: `rules.mag_annotate__dram.input`
- input: `rules.mag_annotate__dram_mags.input`
- input: `rules.mag_annotate__proteinortho.output`
- input: `rules.mag_annotate__phylophlan.output`
- input: `PIPELINE_REPORT / "mag_annotate.pdf"`

### `mag_annotate/bakta.smk`

**`mag_annotate__bakta`**

Run Bakta over the dereplicated mags

- input: `contigs=MAG_CATALOGUE`
- output: `tsv=BAKTA / "bakta.tsv"`
- output: `faa=BAKTA / "bakta.faa"`
- log: `BAKTA / "bakta.log"`
- benchmark: `BAKTA / "benchmark.tsv"`
- params: `out_dir=BAKTA`
- params: `db=features["databases"]["bakta"]`
- params: `options=params["mag_annotate"]["bakta"]["additional_options"]`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: medium_nvme

**`mag_annotate__bakta_mags__run`**

Run Bakta over the dereplicated mags

- input: `contigs=MAGSCOT / "{assembly_id}.fa.gz"`
- output: `tsv=BAKTAMAG / "bakta_{assembly_id}.tsv"`
- output: `faa=BAKTAMAG / "bakta_{assembly_id}.faa"`
- log: `BAKTAMAG / "bakta_{assembly_id}.log"`
- benchmark: `BAKTAMAG / "benchmark_{assembly_id}.tsv"`
- params: `out_dir=BAKTAMAG`
- params: `db=features["databases"]["bakta"]`
- params: `options=params["mag_annotate"]["bakta"]["additional_options"]`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: medium_nvme

**`mag_annotate__bakta_mags`**

Run Bakta over the dereplicated mags

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(BAKTAMAG / "bakta_{assembly_id}.faa", assembly_id=ASSEMBLIES)`

### `mag_annotate/camper.smk`

**`mag_annotate__camper__annotate`**

Annotate dereplicate genomes with CAMPER

- input: `genes=DRAM / "annotate" / "genes.faa"`
- input: `annotation=DRAM / "annotate" / "annotations.tsv"`
- output: `annotation=CAMPER / "annotations.tsv"`
- output: `distill=CAMPER / "distill.tsv"`
- log: `CAMPER / "camper.log"`
- benchmark: `CAMPER / "benchmark.tsv"`
- params: `camper_dir=CAMPER`
- params: `camper_db=features["databases"]["camper"]`
- params: `nvme=config["nvme_storage"]`
- container: `camper` (see `config/.docker.yml`)
- escalation: medium_nvme

**`mag_annotate__camper`**

Run CAMPER on dereplicated genomes.

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.mag_annotate__camper__annotate.output`

### `mag_annotate/checkm2.smk`

**`mag_annotate__checkm2__predict`**

Assess genome completeness/contamination of the dereplicated MAGs with CheckM2

- input: `genomes=MAG_GENOMES`
- input: `reference_data=features["databases"]["checkm2"]`
- output: `CHECKM2 / "quality_report.tsv"`
- log: `CHECKM2 / "quality_report.log"`
- benchmark: `CHECKM2 / "benchmark.tsv"`
- container: `checkm2` (see `config/.docker.yml`)
- escalation: medium_nvme

**`mag_annotate__checkm2`**

Assess all MAGs with CheckM2

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.mag_annotate__checkm2__predict.output`

### `mag_annotate/dram.smk`

**`mag_annotate__dram__annotate`**

Annotate the dereplicated genome catalogue with DRAM

- input: `catalogue=MAG_CATALOGUE`
- input: `taxonomy=GTDBTK / "gtdbtk.summary.tsv"`
- input: `reference_data=features["databases"]["dram"]`
- output: `_DRAM_TABLES / "annotations.tsv"`
- output: `_DRAM_TABLES / "trnas.tsv"`
- output: `_DRAM_TABLES / "rrnas.tsv"`
- output: `_DRAM_TABLES / "genes.faa"`
- log: `DRAM / "annotate.log"`
- benchmark: `DRAM / "benchmark_annotate.tsv"`
- params: `dram_config=config["dram-config"]`
- container: `dram` (see `config/.docker.yml`)
- escalation: large_nvme

**`mag_annotate__fix_dram_annotations_scaffold`**

Patch up DRAM's annotation table (see fix_annotations.py) before distillation

- input: `_DRAM_TABLES / "annotations.tsv"`
- output: `_DRAM_TABLES / "annotations.fixed.tsv"`
- log: `DRAM / "fix_annotation.log"`
- params: `script_folder=SCRIPT_FOLDER`
- container: `assemble` (see `config/.docker.yml`)
- escalation: default

**`mag_annotate__dram__distill`**

Summarize the annotated genomes into DRAM's genome/metabolism reports

- input: `annotations=_DRAM_TABLES / "annotations.fixed.tsv"`
- input: `trnas=_DRAM_TABLES / "trnas.tsv"`
- input: `rrnas=_DRAM_TABLES / "rrnas.tsv"`
- input: `reference_data=features["databases"]["dram"]`
- output: `DRAM / "genome_stats.tsv"`
- output: `DRAM / "metabolism_summary.xlsx"`
- output: `DRAM / "product.html"`
- output: `DRAM / "product.tsv"`
- log: `DRAM / "distill.log2"`
- benchmark: `DRAM / "benchmark_distill.tsv"`
- params: `dram_config=config["dram-config"]`
- container: `dram` (see `config/.docker.yml`)
- escalation: small

**`mag_annotate__dram`**

Run DRAM annotation and distillation over the dereplicated genome catalogue

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.mag_annotate__dram__distill.output`

### `mag_annotate/dram_mag.smk`

**`mag_annotate__dram_mag__annotate`**

Annotate the binned contigs of one assembly with DRAM

- input: `contigs=MAGSCOT / "{assembly_id}.fa.gz"`
- input: `reference_data=features["databases"]["dram"]`
- output: `_DRAM_ASSEMBLY_TABLES / "annotations.tsv"`
- output: `_DRAM_ASSEMBLY_TABLES / "trnas.tsv"`
- output: `_DRAM_ASSEMBLY_TABLES / "rrnas.tsv"`
- log: `_DRAM_ASSEMBLY / "annotate_{assembly_id}.log"`
- benchmark: `_DRAM_ASSEMBLY / "benchmark_annotate.tsv"`
- params: `dram_config=config["dram-config"]`
- params: `tables=lambda wildcards: DRAMMAG / wildcards.assembly_id / "annotate"`
- container: `dram` (see `config/.docker.yml`)
- escalation: large_nvme

**`mag_annotate__fix_dram_mag_annotations_scaffold`**

Patch up DRAM's annotation table (see fix_annotations.py) before distillation

- input: `_DRAM_ASSEMBLY_TABLES / "annotations.tsv"`
- output: `_DRAM_ASSEMBLY_TABLES / "annotations.fixed.tsv"`
- log: `DRAMMAG / "{assembly_id}_fix_annotation.log"`
- params: `script_folder=SCRIPT_FOLDER`
- container: `assemble` (see `config/.docker.yml`)
- escalation: small

**`mag_annotate__dram_mag__distill`**

Summarize the annotated contigs of one assembly into DRAM's genome/metabolism reports

- input: `annotations=_DRAM_ASSEMBLY_TABLES / "annotations.fixed.tsv"`
- input: `trnas=_DRAM_ASSEMBLY_TABLES / "trnas.tsv"`
- input: `rrnas=_DRAM_ASSEMBLY_TABLES / "rrnas.tsv"`
- input: `reference_data=features["databases"]["dram"]`
- output: `_DRAM_ASSEMBLY / "genome_stats.tsv"`
- output: `_DRAM_ASSEMBLY / "metabolism_summary.xlsx"`
- output: `_DRAM_ASSEMBLY / "product.tsv"`
- log: `_DRAM_ASSEMBLY / "distill.log2"`
- benchmark: `_DRAM_ASSEMBLY / "benchmark_distill.tsv"`
- params: `dram_config=config["dram-config"]`
- params: `assembly_folder=lambda wildcards: DRAMMAG / wildcards.assembly_id`
- container: `dram` (see `config/.docker.yml`)
- escalation: medium

**`mag_annotate__dram_mags`**

Run DRAM over the sample-wise mags

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(_DRAM_ASSEMBLY / "genome_stats.tsv", assembly_id=ASSEMBLIES)`

### `mag_annotate/eggnog.smk`

**`mag_annotate__eggnog`**

Run eggnog over the dereplicated mags

- input: `contigs=MAG_CATALOGUE`
- output: `directory(EGGNOG)`
- log: `protected(EGGNOG / "eggnog.log")`
- benchmark: `EGGNOG / "benchmark.tsv"`
- params: `out_dir=EGGNOG`
- params: `db=features["databases"]["eggnog"]`
- params: `prefix="eggnog"`
- params: `tmp_dir=lambda wc: f"{config['tmp_storage']}/mag_annotate__eggnog"`
- container: `eggnog` (see `config/.docker.yml`)
- escalation: large_nvme

### `mag_annotate/gtdbtk.smk`

**`mag_annotate__gtdbtk__classify`**

Place the MAGs in the GTDB taxonomy with the classify workflow of GTDB-Tk

- input: `genomes=MAG_GENOMES`
- input: `reference_data=features["databases"]["gtdbtk"]`
- output: `merged_summary=GTDBTK / "gtdbtk.summary.tsv"`
- output: `archives=expand(GTDBTK / "{part}.tar.gz", part=("align", "classify", "identify"))`
- log: `GTDBTK / "gtdbtk_classify.log"`
- benchmark: `GTDBTK / "benchmark.tsv"`
- container: `gtdbtk` (see `config/.docker.yml`)
- escalation: large

**`mag_annotate__gtdbtk`**

Classify the MAGs with GTDB-Tk

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.mag_annotate__gtdbtk__classify.output`

### `mag_annotate/phylophlan.smk`

**`mag_annotate__phylophlan`**

Run phylophlan for the dereplicated genomes

- input: `MAG_GENOMES`
- output: `folder=directory(PHYLOPHLAN / "SGB")`
- output: `result=PHYLOPHLAN / "SGB" / "SGB.tsv"`
- log: `PHYLOPHLAN / "phylophlan_sgb.log"`
- benchmark: `PHYLOPHLAN / "benchmark/phylophlan_sgb.tsv"`
- params: `result=PHYLOPHLAN / "SGB" / "SGB"`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: medium_nvme

### `mag_annotate/proteinortho.smk`

**`mag_annotate__proteinortho`**

Run Proteinortho over all bakta output FAA files together

- input: `faa=expand(BAKTAMAG / "bakta_{assembly_id}.faa", assembly_id=ASSEMBLIES)`
- output: `tsv=PROTEINORTHO / "proteinortho.proteinortho.tsv"`
- log: `PROTEINORTHO / "proteinortho.log"`
- benchmark: `PROTEINORTHO / "benchmark.tsv"`
- params: `outdir=PROTEINORTHO`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: medium

### `mag_annotate/quast.smk`

**`mag_annotate__quast`**

Assembly statistics of the MAG catalogue with QUAST

- input: `MAG_CATALOGUE`
- output: `directory(QUAST)`
- log: `QUAST / "quast.log"`
- benchmark: `QUAST / "benchmark.tsv"`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: medium

## Module `contig_annotate`

### `contig_annotate/__main__.smk`

**`contig_annotate`**

Annotate on contig level

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.contig_annotate__camper.input`
- input: `[CONTIG_EGGNOG / f"{assembly_id}/eggnog_output.emapper.annotations" for assembly_id in ASSEMBLIES]`
- input: `lambda wildcards: [CONTIG_FEATURECOUNTS / f"{assembly_id}/{assembly_id}_{sample_id}.{library_id}.prodigal_fc.txt" for assembly_id, sample_id, library_id in ASSEMBLY_LIBRARIES]`
- input: `rules.contig_annotate__diamond.input`
- input: `rules.contig_annotate__hmmer.input`
- input: `rules.contig_annotate__eggnog7.input`
- input: `PIPELINE_REPORT / "contig_annotate.pdf"`

**`contig_annotate_extra`**

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.contig_annotate__ncyc.input`

### `contig_annotate/camper.smk`

**`contig_annotate__camper__annotate`**

Annotate dereplicate genomes with CAMPER

- input: `fa=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.fa"`
- output: `annotation=CONTIG_CAMPER / "{assembly_id}" / "annotations.tsv"`
- output: `distillate=CONTIG_CAMPER / "{assembly_id}" / "distillate.tsv"`
- log: `CONTIG_CAMPER / "{assembly_id}.log"`
- benchmark: `CONTIG_CAMPER / "benchmark/{assembly_id}.tsv"`
- params: `camper_dir=CONTIG_CAMPER`
- params: `out_dir=lambda wildcards: f"{CONTIG_CAMPER}/{wildcards.assembly_id}"`
- params: `camper_db=features["databases"]["camper"]`
- params: `nvme=config["nvme_storage"]`
- params: `sample=lambda wildcards: f"{wildcards.assembly_id}"`
- container: `camper` (see `config/.docker.yml`)
- escalation: medium_nvme

**`contig_annotate__camper`**

Run CAMPER on contig gene sequences.

Target rule: it runs nothing itself and only asks for these files.

- input: `[CONTIG_CAMPER / f"{assembly_id}" / "annotations.tsv" for assembly_id in ASSEMBLIES]`

### `contig_annotate/diamond.smk`

**`contig_annotate__diamond__assign`**

Run Diamond with SHM/NVME staging if possible.

- input: `fa=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.fa"`
- input: `database=lambda w: features["databases"]["diamond_contig_protein"][w.diamond_db]`
- output: `CONTIG_DIAMOND / "{diamond_db}" / "{assembly_id}.out"`
- log: `CONTIG_DIAMOND / "{diamond_db}_{assembly_id}.log"`
- benchmark: `CONTIG_DIAMOND / "benchmark/{diamond_db}_{assembly_id}.tsv"`
- params: `max_attempt=len(get_escalation_order("contig_annotate__diamond__assign"))`
- params: `in_folder=FASTP`
- params: `out_folder=lambda w: CONTIG_DIAMOND / w.diamond_db`
- params: `run_in_shm=config["diamond_shm"]`
- params: `copy_dbs=config["copy_dbs"]`
- params: `diamond_shm=DIAMONDSHM`
- params: `diamond_nvme=DIAMONDNVME`
- params: `diamond_db_shm=lambda w: os.path.join(DIAMONDSHM, w.diamond_db)`
- params: `diamond_path=lambda w: os.path.basename(features["databases"]["diamond_contig_protein"][w.diamond_db])`
- params: `diamond_db_nvme=lambda w: os.path.join(DIAMONDNVME, w.diamond_db)`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: medium_nvme

**`contig_annotate__diamond__summarise`**

Run R script to summarise Diamond results

- input: `lambda w: [CONTIG_DIAMOND / w.diamond_db / f"{assembly_id}.out" for assembly_id in ASSEMBLIES]`
- output: `CONTIG_DIAMOND / "{diamond_db}" / "summary_a.tsv"`
- output: `CONTIG_DIAMOND / "{diamond_db}" / "summary_b.tsv"`
- log: `CONTIG_DIAMOND / "{diamond_db}" / "contig_annotate__diamond__summarise.log"`
- benchmark: `CONTIG_DIAMOND / "{diamond_db}" / "benchmark_summarise.tsv"`
- params: `script=lambda w: config["pipeline_folder"] + "workflow/scripts/downstream_scripts/create_featuretable_diamond_" + w.diamond_db + ".R"`
- params: `project_folder=WD`
- params: `database=lambda w: w.diamond_db`
- container: `r_report` (see `config/.docker.yml`)
- escalation: small

**`contig_annotate__diamond`**

Run all Diamond steps

Target rule: it runs nothing itself and only asks for these files.

- input: `[CONTIG_DIAMOND / diamond_db / f"{assembly_id}.out" for assembly_id in ASSEMBLIES for diamond_db in features["databases"]["diamond_contig_protein"]]`

### `contig_annotate/eggnog.smk`

**`contig_annotate__eggnog_find_homology`**

Find homolog genes in data (EGGNOG).

- input: `folder=CONTIG_PRODIGAL / "{assembly_id}/Chunks/"`
- input: `files=CONTIG_PRODIGAL / "{assembly_id}/Chunks/prodigal.chunk.{i}"`
- output: `file=CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.seed_orthologs"`
- log: `CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.log"`
- benchmark: `CONTIG_EGGNOG / "{assembly_id}/Chunks/benchmark_homology.{i}.tsv"`
- params: `folder=lambda wildcards: CONTIG_EGGNOG / f"{wildcards.assembly_id}/Chunks/"`
- params: `tmp=config["nvme_storage"]`
- params: `out="prodigal.chunk.{i}"`
- params: `fa=features["databases"]["eggnog"]`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: medium_nvme

**`contig_annotate__eggnog_orthology_chunk`**

Annotate eggnog hits table per chunk (EGGNOG) using /dev/shm for speed, with usage counter to ensure DB is only deleted once all jobs are finished.

- input: `seed=CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.seed_orthologs"`
- output: `annotation=CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations"`
- output: `done=CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations.done"`
- log: `CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations.log"`
- benchmark: `CONTIG_EGGNOG / "{assembly_id}/Chunks/benchmark_orthology.{i}.tsv"`
- params: `fa=features["databases"]["eggnog"]`
- params: `out=lambda wc: f"prodigal.chunk.{wc.i}"`
- params: `outdir=lambda wc: CONTIG_EGGNOG / f"{wc.assembly_id}/Chunks"`
- params: `run_in_shm=config["eggnog_shm"]`
- params: `copy_dbs=config["copy_dbs"]`
- params: `shm=config["shm_storage"]`
- params: `nvme=config["nvme_storage"]`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: large_nvme

**`contig_annotate__eggnog_merge_annotations`**

- input: `contig_annotate_aggregate_annotations_eggnog_search`
- output: `CONTIG_EGGNOG / "{assembly_id}/eggnog_output.emapper.annotations"`
- log: `CONTIG_EGGNOG / "{assembly_id}/eggnog_output.emapper.annotations.log"`
- benchmark: `CONTIG_EGGNOG / "{assembly_id}/benchmark_merge_annotations.tsv"`
- escalation: default

**`contig_annotate__eggnog`**

Run eggnog on all assemblies

Target rule: it runs nothing itself and only asks for these files.

- input: `[CONTIG_EGGNOG / f"{assembly_id}/eggnog_output.emapper.annotations" for assembly_id in ASSEMBLIES]`

### `contig_annotate/eggnog7.smk`

**`contig_annotate__eggnog7__run`**

Run the eggnog annotator for version 7

- input: `fa=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.fa"`
- output: `CONTIG_EGGNOG7 / "{assembly_id}/{assembly_id}.eggnog.tsv.gz"`
- log: `CONTIG_EGGNOG7 / "logs/{assembly_id}_eggnog.log"`
- benchmark: `CONTIG_EGGNOG7 / "benchmark/{assembly_id}.tsv"`
- params: `sample=lambda wildcards: f"{wildcards.assembly_id}"`
- params: `out=CONTIG_EGGNOG7`
- params: `db=features["databases"]["eggnog7"]`
- params: `folder=config["pipeline_folder"]`
- container: `eggnog` (see `config/.docker.yml`)
- escalation: medium

**`contig_annotate__eggnog7`**

Run eggnog on all assemblies

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(CONTIG_EGGNOG7 / "{assembly_id}/{assembly_id}.eggnog.tsv.gz", assembly_id=ASSEMBLIES)`

### `contig_annotate/featurecounts.smk`

**`contig_annotate__cram_to_bam`**

Create temporary bam-files for quantification

- input: `ASSEMBLY_MAPPING / "{assembly_id}.{sample_id}.{library_id}.cram"`
- output: `temp(ASSEMBLY_MAPPING / "{assembly_id}.{sample_id}.{library_id}.bam")`
- log: `log=ASSEMBLY_MAPPING / "{assembly_id}.{sample_id}.{library_id}.cramToBam.log"`
- container: `assemble` (see `config/.docker.yml`)
- escalation: small

**`contig_annotate__featurecounts__run`**

Quantify the mapped assembly reads in predicted genes (featureCounts).

- input: `bam=ASSEMBLY_MAPPING / "{assembly_id}.{sample_id}.{library_id}.bam"`
- input: `gtf=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.gtf"`
- output: `file=CONTIG_FEATURECOUNTS / "{assembly_id}/{assembly_id}_{sample_id}.{library_id}.prodigal_fc.txt"`
- log: `CONTIG_FEATURECOUNTS / "{assembly_id}/{assembly_id}_{sample_id}.{library_id}.prodigal_fc.log"`
- container: `subread` (see `config/.docker.yml`)
- escalation: medium

**`contig_annotate__featurecounts`**

Quantify all samples for all the assemblies that they belong to

Target rule: it runs nothing itself and only asks for these files.

- input: `[CONTIG_FEATURECOUNTS / f"{assembly_id}/{assembly_id}_{sample_id}.{library_id}.prodigal_fc.txt" for assembly_id, sample_id, library_id in ASSEMBLY_LIBRARIES]`

### `contig_annotate/hmmer.smk`

**`contig_annotate__hmmer__assign`**

Run HMMER.

- input: `fa=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.fa"`
- input: `database=lambda w: features["databases"]["hmmer"][w.hmmer_db]`
- output: `out=CONTIG_HMMER / "{hmmer_db}" / "{assembly_id}.out"`
- output: `aln=CONTIG_HMMER / "{hmmer_db}" / "{assembly_id}.aln"`
- output: `tblout=CONTIG_HMMER / "{hmmer_db}" / "{assembly_id}.tblout.tsv"`
- output: `domtblout=CONTIG_HMMER / "{hmmer_db}" / "{assembly_id}.domains-tblout.tsv"`
- output: `pfam=CONTIG_HMMER / "{hmmer_db}" / "{assembly_id}.pfam"`
- log: `CONTIG_HMMER / "{hmmer_db}_{assembly_id}.log"`
- benchmark: `CONTIG_HMMER / "benchmark/{hmmer_db}_{assembly_id}.tsv"`
- params: `out_folder=lambda w: CONTIG_HMMER / w.hmmer_db`
- params: `domt=lambda w: params["contig_annotate"]["hmmer"]["domt"].get(w.hmmer_db, params["contig_annotate"]["hmmer"]["domt"]["fallback"])`
- container: `assemble` (see `config/.docker.yml`)
- escalation: medium_nvme

**`contig_annotate__hmmer`**

Run all HMMER steps

Target rule: it runs nothing itself and only asks for these files.

- input: `[CONTIG_HMMER / hmmer_db / f"{assembly_id}.out" for assembly_id in ASSEMBLIES for hmmer_db in features["databases"]["hmmer"]]`

### `contig_annotate/ncyc.smk`

**`contig_annotate__ncyc__prepare_input`**

Create sample sheet for NCycDB Perl wrapper (runs all samples at once)

- input: `[CONTIG_PRODIGAL / f"{assembly_id}/{assembly_id}.prodigal.fa" for assembly_id in ASSEMBLIES]`
- output: `CONTIG_NCYC / "ncyc_samples.tsv"`
- log: `CONTIG_NCYC / "log" / "ncyc_samples.log"`
- benchmark: `CONTIG_NCYC / "benchmark" / "ncyc_samples.tsv"`
- params: `folder=config["pipeline_folder"]`
- params: `input_dir=CONTIG_NCYC / "input"`
- params: `outdir=NCYC / "results"`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: small

**`contig_annotate__ncyc__run`**

Run NCycDB Perl wrapper on all samples from prodigal

- input: `CONTIG_NCYC / "ncyc_samples.tsv"`
- output: `CONTIG_NCYC / "ncyc_results.tsv"`
- log: `CONTIG_NCYC / "log" / "ncyc_run.log"`
- benchmark: `CONTIG_NCYC / "benchmark" / "ncyc_run.tsv"`
- params: `folder=config["pipeline_folder"]`
- params: `outdir=CONTIG_NCYC`
- params: `input_dir=CONTIG_NCYC / "input"`
- params: `faa=features["databases"]["ncyc"]`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: medium

**`contig_annotate__ncyc`**

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.contig_annotate__ncyc__run.output`

### `contig_annotate/prodigal.smk`

**`contig_annotate__prodigal__run`**

Predict genes from assemblies (PRODIGAL).

- input: `assembly=CONTIGS`
- output: `fa=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.fa"`
- output: `gtf=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.gtf"`
- output: `gtfplain=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal_plain.gtf"`
- log: `CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.log"`
- benchmark: `CONTIG_PRODIGAL / "benchmark/{assembly_id}.tsv"`
- container: `assemble` (see `config/.docker.yml`)
- escalation: medium

**`contig_annotate__cut_prodigal`**

Cut prodigal output into smaller contigs (BASH).

- input: `fa=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.fa"`
- output: `directory(CONTIG_PRODIGAL / "{assembly_id}/Chunks/")`
- log: `CONTIG_PRODIGAL / "logs/{assembly_id}_cut_prodigal.log"`
- benchmark: `CONTIG_PRODIGAL / "benchmark/{assembly_id}_cut_prodigal.tsv"`
- params: `out=lambda wildcards: CONTIG_PRODIGAL / f"{wildcards.assembly_id}/Chunks/prodigal.chunk"`
- params: `folder=config["pipeline_folder"]`
- params: `split=params["contig_annotate"]["prodigal"]["split"]`
- container: `mag_annotate` (see `config/.docker.yml`)
- escalation: medium

**`contig_annotate__prodigal`**

Run prodigal on all assemblies

Target rule: it runs nothing itself and only asks for these files.

- input: `expand(CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.fa", assembly_id=ASSEMBLIES)`

## Module `eukaryote`

### `eukaryote/4cac.smk`

**`eukaryote__4cac__extract_graph`**

Pull one assembly's contigs, contig paths and assembly graph out of the metaSPAdes tarball 4CAC reads scaffolds.fasta and scaffolds.paths. The pipeline's contigs are metaSPAdes' contigs.fasta, and contigs.paths has the same format as scaffolds.paths, so both are extracted under the scaffold names: 4CAC then classifies exactly the contigs the rest of the pipeline uses.

- input: `tarball=METASPADES / "{assembly_id}.tar.gz"`
- output: `contigs=temp(EUK_4CAC / "{assembly_id}" / "scaffolds.fasta")`
- output: `paths=temp(EUK_4CAC / "{assembly_id}" / "scaffolds.paths")`
- output: `graph=temp(EUK_4CAC / "{assembly_id}" / "assembly_graph_with_scaffolds.gfa")`
- log: `EUK_4CAC / "{assembly_id}.extract_graph.log"`
- benchmark: `EUK_4CAC / "benchmark/{assembly_id}.extract_graph.tsv"`
- params: `tmp_dir=lambda w: EUK_4CAC / w.assembly_id / "extract_tmp"`
- container: `assemble` (see `config/.docker.yml`)
- escalation: small, medium

**`eukaryote__4cac__run`**

Classify one metaSPAdes assembly's contigs with 4CAC (XGBoost, refined on the assembly graph) Columns: contig_id (pipeline name), node_id (metaSPAdes name), class (phage, plasmid, prokarya, eukarya, uncertain), then the four XGBoost scores the graph step started from.

- input: `contigs=EUK_4CAC / "{assembly_id}" / "scaffolds.fasta"`
- input: `paths=EUK_4CAC / "{assembly_id}" / "scaffolds.paths"`
- input: `graph=EUK_4CAC / "{assembly_id}" / "assembly_graph_with_scaffolds.gfa"`
- output: `tsv=EUK_4CAC / "{assembly_id}.tsv"`
- log: `EUK_4CAC / "{assembly_id}.log"`
- benchmark: `EUK_4CAC / "benchmark/{assembly_id}.tsv"`
- params: `workdir=lambda w: EUK_4CAC / w.assembly_id`
- params: `install_dir=params["eukaryote"]["4cac"]["install_dir"]`
- params: `phage=params["eukaryote"]["4cac"]["phage"]`
- params: `plasmid=params["eukaryote"]["4cac"]["plasmid"]`
- params: `script_folder=SCRIPT_FOLDER`
- container: `4cac` (see `config/.docker.yml`)
- escalation: medium, large, highmem

**`eukaryote__4cac`**

Run 4CAC on every assembly (metaSPAdes assemblies only, see FOURCAC_SUPPORTED)

Target rule: it runs nothing itself and only asks for these files.

- input: `[EUK_4CAC / f"{assembly_id}.tsv" for assembly_id in ASSEMBLIES] if FOURCAC_SUPPORTED else []`

### `eukaryote/__main__.smk`

**`eukaryote`**

Classify contigs as eukaryotic or prokaryotic (Tiara, 4CAC, REMAG) and bin the eukaryotic ones (REMAG)

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.eukaryote__tiara.input`
- input: `rules.eukaryote__4cac.input`
- input: `rules.eukaryote__remag.input`
- input: `PIPELINE_REPORT / "eukaryote.pdf"`

### `eukaryote/remag.smk`

**`eukaryote__remag__filter`**

Classify one assembly's contigs with REMAG's HyenaDNA eukaryote filter Columns: contig_id, length, prediction (eukaryote / non_eukaryote), eukaryote_prob, confidence, num_windows, resampled. Contigs shorter than min_contig_length are not in it. REMAG names its files after the input ({assembly_id}.fa.gz -> {assembly_id}.fa_*). The classification table is copied next to the other tools' tables; the REMAG folder is kept as is, because eukaryote__remag__bin resumes from it. If the classifier can't be loaded, or a batch fails, REMAG keeps those contigs as eukaryotic and only logs it; both are turned into failures here.

- input: `assembly=CONTIGS`
- output: `tsv=EUK_REMAG / "{assembly_id}.tsv"`
- output: `filtered=EUK_REMAG / "{assembly_id}" / "{assembly_id}.fa_eukaryotic_filtered.fasta"`
- log: `EUK_REMAG / "{assembly_id}.filter.log"`
- benchmark: `EUK_REMAG / "benchmark/{assembly_id}.filter.tsv"`
- params: `out_dir=lambda w: EUK_REMAG / w.assembly_id`
- params: `min_contig_length=params["eukaryote"]["remag"]["min_contig_length"]`
- params: `hyenadna_batch_size=params["eukaryote"]["remag"]["hyenadna_batch_size"]`
- container: `remag` (see `config/.docker.yml`)
- escalation: medium, large, longrun

**`eukaryote__remag__bin`**

Bin one assembly's eukaryotic contigs with REMAG Runs in eukaryote__remag__filter's folder, where REMAG finds its own filtered FASTA and skips classifying again. Skipped, with an empty bins folder and a header-only bins.csv, when the contigs called eukaryotic add up to less than min_bin_size: no bin could pass the size cutoff then, and REMAG exits with an error when it has (nearly) nothing to bin.

- input: `assembly=CONTIGS`
- input: `tsv=EUK_REMAG / "{assembly_id}.tsv"`
- input: `filtered=EUK_REMAG / "{assembly_id}" / "{assembly_id}.fa_eukaryotic_filtered.fasta"`
- input: `alignments=assembly_alignments`
- input: `indexes=assembly_alignment_indexes`
- output: `bins=directory(EUK_REMAG / "{assembly_id}" / "bins")`
- output: `assignments=EUK_REMAG / "{assembly_id}" / "bins.csv"`
- log: `EUK_REMAG / "{assembly_id}.bin.log"`
- benchmark: `EUK_REMAG / "benchmark/{assembly_id}.bin.tsv"`
- params: `out_dir=lambda w: EUK_REMAG / w.assembly_id`
- params: `coverage=compose_coverage_args_for_remag`
- params: `min_contig_length=params["eukaryote"]["remag"]["min_contig_length"]`
- params: `min_bin_size=params["eukaryote"]["remag"]["min_bin_size"]`
- params: `hyenadna_batch_size=params["eukaryote"]["remag"]["hyenadna_batch_size"]`
- params: `extra=params["eukaryote"]["remag"]["extra"]`
- container: `remag` (see `config/.docker.yml`)
- escalation: large, longrun, highmem_longrun

**`eukaryote__remag`**

Run REMAG's eukaryote filter and binning on every assembly

Target rule: it runs nothing itself and only asks for these files.

- input: `[EUK_REMAG / f"{assembly_id}.tsv" for assembly_id in ASSEMBLIES]`
- input: `[EUK_REMAG / f"{assembly_id}" / "bins.csv" for assembly_id in ASSEMBLIES]`

### `eukaryote/tiara.smk`

**`eukaryote__tiara__run`**

Classify one assembly's contigs with Tiara (prokaryote / eukaryote / organelle) Columns: sequence_id, class_fst_stage (archaea, bacteria, prokarya, eukarya, organelle, unknown), class_snd_stage (mitochondrion, plastid, unknown for organelles, n/a otherwise), then the per-class probabilities. Contigs shorter than min_len are not in the table. Tiara writes its class counts next to the table as log_<table name>.

- input: `assembly=CONTIGS`
- output: `tsv=EUK_TIARA / "{assembly_id}.tsv"`
- output: `summary=EUK_TIARA / "log_{assembly_id}.tsv"`
- log: `EUK_TIARA / "{assembly_id}.log"`
- benchmark: `EUK_TIARA / "benchmark/{assembly_id}.tsv"`
- params: `min_len=params["eukaryote"]["tiara"]["min_len"]`
- params: `prob_cutoff=params["eukaryote"]["tiara"]["prob_cutoff"]`
- container: `tiara` (see `config/.docker.yml`)
- escalation: medium, large

**`eukaryote__tiara`**

Run Tiara on every assembly

Target rule: it runs nothing itself and only asks for these files.

- input: `[EUK_TIARA / f"{assembly_id}.tsv" for assembly_id in ASSEMBLIES]`

## Module `report`

### `report/__main__.smk`

**`report`**

Generate the report of every module of the rule all. The module eukaryote is optional, and has its own target report_eukaryote

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.report__assemble.output`
- input: `rules.report__contig_annotate.output`
- input: `rules.report__mag_annotate.output`
- input: `rules.report__preprocess.output`
- input: `rules.report__quantify.output`
- input: `rules.report__read_annotate.output`
- input: `rules.report__reads.output`
- input: `rules.report__reference.output`

**`report_assemble`**

Report on the module assemble

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.report__assemble.output`

**`report_contig_annotate`**

Report on the module contig_annotate

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.report__contig_annotate.output`

**`report_eukaryote`**

Report on the module eukaryote

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.report__eukaryote.output`

**`report_mag_annotate`**

Report on the module mag_annotate

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.report__mag_annotate.output`

**`report_preprocess`**

Report on the module preprocess

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.report__preprocess.output`

**`report_quantify`**

Report on the module quantify

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.report__quantify.output`

**`report_read_annotate`**

Report on the module read_annotate

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.report__read_annotate.output`

**`report_reads`**

Report on the module reads

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.report__reads.output`

**`report_reference`**

Report on the module reference

Target rule: it runs nothing itself and only asks for these files.

- input: `rules.report__reference.output`

### `report/assemble.smk`

**`report__assemble`**

Report on assembly, binning and the genome catalogue, data volume and resources

- input: `module_results(rules.assemble, "assemble")`
- output: `pdf=PIPELINE_REPORT / "assemble.pdf"`
- output: `folder=directory(PIPELINE_REPORT / "assemble")`
- log: `PIPELINE_REPORT / "assemble.log"`
- benchmark: `PIPELINE_REPORT / "assemble_benchmark.tsv"`
- params: `script=REPORT_SCRIPT`
- params: `pipeline_folder=config["pipeline_folder"]`
- params: `features=config["features-file"]`
- params: `sample_file=config["sample-file"]`
- params: `project_folder=WD`
- params: `rule_table=lambda wc: report_rule_table("assemble")`
- params: `version=version`
- params: `snakemake_version=SNAKEMAKE_VERSION`
- escalation: small, medium

### `report/contig_annotate.smk`

**`report__contig_annotate`**

Report on genes and annotation of the contigs, data volume and resources

- input: `module_results(rules.contig_annotate, "contig_annotate")`
- output: `pdf=PIPELINE_REPORT / "contig_annotate.pdf"`
- output: `folder=directory(PIPELINE_REPORT / "contig_annotate")`
- log: `PIPELINE_REPORT / "contig_annotate.log"`
- benchmark: `PIPELINE_REPORT / "contig_annotate_benchmark.tsv"`
- params: `script=REPORT_SCRIPT`
- params: `pipeline_folder=config["pipeline_folder"]`
- params: `features=config["features-file"]`
- params: `sample_file=config["sample-file"]`
- params: `project_folder=WD`
- params: `rule_table=lambda wc: report_rule_table("contig_annotate")`
- params: `version=version`
- params: `snakemake_version=SNAKEMAKE_VERSION`
- escalation: small, medium

### `report/eukaryote.smk`

**`report__eukaryote`**

Report on eukaryotic contigs and bins, data volume and resources

- input: `module_results(rules.eukaryote, "eukaryote")`
- output: `pdf=PIPELINE_REPORT / "eukaryote.pdf"`
- output: `folder=directory(PIPELINE_REPORT / "eukaryote")`
- log: `PIPELINE_REPORT / "eukaryote.log"`
- benchmark: `PIPELINE_REPORT / "eukaryote_benchmark.tsv"`
- params: `script=REPORT_SCRIPT`
- params: `pipeline_folder=config["pipeline_folder"]`
- params: `features=config["features-file"]`
- params: `sample_file=config["sample-file"]`
- params: `project_folder=WD`
- params: `rule_table=lambda wc: report_rule_table("eukaryote")`
- params: `version=version`
- params: `snakemake_version=SNAKEMAKE_VERSION`
- escalation: small, medium

### `report/mag_annotate.smk`

**`report__mag_annotate`**

Report on genome quality, taxonomy and annotation, data volume and resources

- input: `module_results(rules.mag_annotate, "mag_annotate")`
- output: `pdf=PIPELINE_REPORT / "mag_annotate.pdf"`
- output: `folder=directory(PIPELINE_REPORT / "mag_annotate")`
- log: `PIPELINE_REPORT / "mag_annotate.log"`
- benchmark: `PIPELINE_REPORT / "mag_annotate_benchmark.tsv"`
- params: `script=REPORT_SCRIPT`
- params: `pipeline_folder=config["pipeline_folder"]`
- params: `features=config["features-file"]`
- params: `sample_file=config["sample-file"]`
- params: `project_folder=WD`
- params: `rule_table=lambda wc: report_rule_table("mag_annotate")`
- params: `version=version`
- params: `snakemake_version=SNAKEMAKE_VERSION`
- escalation: small, medium

### `report/preprocess.smk`

**`report__preprocess`**

Report on trimming and host removal: what happened to the reads, data volume and resources

- input: `module_results(rules.preprocess, "preprocess")`
- output: `pdf=PIPELINE_REPORT / "preprocess.pdf"`
- output: `folder=directory(PIPELINE_REPORT / "preprocess")`
- log: `PIPELINE_REPORT / "preprocess.log"`
- benchmark: `PIPELINE_REPORT / "preprocess_benchmark.tsv"`
- params: `script=REPORT_SCRIPT`
- params: `pipeline_folder=config["pipeline_folder"]`
- params: `features=config["features-file"]`
- params: `sample_file=config["sample-file"]`
- params: `project_folder=WD`
- params: `rule_table=lambda wc: report_rule_table("preprocess")`
- params: `version=version`
- params: `snakemake_version=SNAKEMAKE_VERSION`
- escalation: small, medium

### `report/quantify.smk`

**`report__quantify`**

Report on the abundance of genomes and contigs, data volume and resources

- input: `module_results(rules.quantify, "quantify")`
- output: `pdf=PIPELINE_REPORT / "quantify.pdf"`
- output: `folder=directory(PIPELINE_REPORT / "quantify")`
- log: `PIPELINE_REPORT / "quantify.log"`
- benchmark: `PIPELINE_REPORT / "quantify_benchmark.tsv"`
- params: `script=REPORT_SCRIPT`
- params: `pipeline_folder=config["pipeline_folder"]`
- params: `features=config["features-file"]`
- params: `sample_file=config["sample-file"]`
- params: `project_folder=WD`
- params: `rule_table=lambda wc: report_rule_table("quantify")`
- params: `version=version`
- params: `snakemake_version=SNAKEMAKE_VERSION`
- escalation: small, medium

### `report/read_annotate.smk`

**`report__read_annotate`**

Report on the read-based taxonomy and function, data volume and resources

- input: `module_results(rules.read_annotate, "read_annotate")`
- output: `pdf=PIPELINE_REPORT / "read_annotate.pdf"`
- output: `folder=directory(PIPELINE_REPORT / "read_annotate")`
- log: `PIPELINE_REPORT / "read_annotate.log"`
- benchmark: `PIPELINE_REPORT / "read_annotate_benchmark.tsv"`
- params: `script=REPORT_SCRIPT`
- params: `pipeline_folder=config["pipeline_folder"]`
- params: `features=config["features-file"]`
- params: `sample_file=config["sample-file"]`
- params: `project_folder=WD`
- params: `rule_table=lambda wc: report_rule_table("read_annotate")`
- params: `version=version`
- params: `snakemake_version=SNAKEMAKE_VERSION`
- escalation: small, medium

### `report/reads.smk`

**`report__reads`**

Report on the raw reads: samples, read numbers, quality, data volume and resources

- input: `module_results(rules.reads, "reads")`
- output: `pdf=PIPELINE_REPORT / "reads.pdf"`
- output: `folder=directory(PIPELINE_REPORT / "reads")`
- log: `PIPELINE_REPORT / "reads.log"`
- benchmark: `PIPELINE_REPORT / "reads_benchmark.tsv"`
- params: `script=REPORT_SCRIPT`
- params: `pipeline_folder=config["pipeline_folder"]`
- params: `features=config["features-file"]`
- params: `sample_file=config["sample-file"]`
- params: `project_folder=WD`
- params: `rule_table=lambda wc: report_rule_table("reads")`
- params: `version=version`
- params: `snakemake_version=SNAKEMAKE_VERSION`
- escalation: small, medium

### `report/reference.smk`

**`report__reference`**

Report on the host genomes and the configured databases, data volume and resources

- input: `module_results(rules.reference, "reference")`
- output: `pdf=PIPELINE_REPORT / "reference.pdf"`
- output: `folder=directory(PIPELINE_REPORT / "reference")`
- log: `PIPELINE_REPORT / "reference.log"`
- benchmark: `PIPELINE_REPORT / "reference_benchmark.tsv"`
- params: `script=REPORT_SCRIPT`
- params: `pipeline_folder=config["pipeline_folder"]`
- params: `features=config["features-file"]`
- params: `sample_file=config["sample-file"]`
- params: `project_folder=WD`
- params: `rule_table=lambda wc: report_rule_table("reference")`
- params: `version=version`
- params: `snakemake_version=SNAKEMAKE_VERSION`
- escalation: small, medium

## Module `helpers`

### `helpers/fastqc.smk`

**`helpers__fastqc`**

Generic FastQC rule: report for any {prefix}.fq.gz, reused across modules

- input: `"{prefix}.fq.gz"`
- output: `html="{prefix}_fastqc.html"`
- output: `zip="{prefix}_fastqc.zip"`
- log: `"{prefix}_fastqc.log"`
- benchmark: `"{prefix}_fastqc_benchmark.tsv"`
- container: `helpers` (see `config/.docker.yml`)
- escalation: small

### `helpers/samtools.smk`

**`helpers__samtools__index_bam`**

samtools index of a BAM

- input: `"{prefix}.bam"`
- output: `"{prefix}.bam.bai"`
- log: `"{prefix}.bam.bai.log"`
- benchmark: `"benchmark/{prefix}.bam.bai.tsv"`
- container: `helpers` (see `config/.docker.yml`)
- escalation: medium

**`helpers__samtools__index_cram`**

samtools index of a CRAM

- input: `"{prefix}.cram"`
- output: `"{prefix}.cram.crai"`
- log: `"{prefix}.cram.crai.log"`
- benchmark: `"benchmark/{prefix}.cram.crai.tsv"`
- container: `helpers` (see `config/.docker.yml`)
- escalation: small

**`helpers__samtools__faidx_fa`**

samtools faidx of a plain FASTA

- input: `"{prefix}.fa"`
- output: `"{prefix}.fa.fai"`
- log: `"{prefix}.fa.fai.log"`
- benchmark: `"benchmark/{prefix}.fa.fai.tsv"`
- container: `helpers` (see `config/.docker.yml`)
- escalation: small

**`helpers__samtools__faidx_fagz`**

samtools faidx of a bgzipped FASTA

- input: `"{prefix}.fa.gz"`
- output: `fai="{prefix}.fa.gz.fai"`
- output: `gzi="{prefix}.fa.gz.gzi"`
- log: `"{prefix}.fa.gz.log"`
- benchmark: `"benchmark/{prefix}.fa.gz.tsv"`
- container: `helpers` (see `config/.docker.yml`)
- escalation: small

**`helpers__samtools__idxstats_cram`**

samtools idxstats of a CRAM

- input: `cram="{prefix}.cram"`
- input: `crai="{prefix}.cram.crai"`
- output: `tsv="{prefix}.idxstats.tsv"`
- log: `"{prefix}.idxstats.log"`
- benchmark: `"benchmark/{prefix}.idxstats.tsv"`
- container: `helpers` (see `config/.docker.yml`)
- escalation: small

**`helpers__samtools__flagstats_cram`**

samtools flagstats of a CRAM

- input: `cram="{prefix}.cram"`
- input: `crai="{prefix}.cram.crai"`
- output: `txt="{prefix}.flagstats.txt"`
- log: `"{prefix}.flagstats.log"`
- container: `helpers` (see `config/.docker.yml`)
- escalation: small

## Module `devel`

### `devel/throw_error.smk`

**`test_error`**

- output: `"done.txt"`
- log: `"log_file.txt"`
- params: `fail_at_sec=20`
- escalation: small

---

This reference lists 173 rules.
