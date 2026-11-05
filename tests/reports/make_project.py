#!/usr/bin/env python3
"""Write a small project with output files of all tools, to test the module reports.

Usage: make_project.py <new folder> <pipeline folder> [--empty | --broken]

The numbers are made up, except that they fit together, so that check_project.py can compare the
reports with them. The formats follow the tools' documentation. Some of them were checked against
real output (see expected_real.tsv), the others only can be once those tools have run on a cluster.
The benchmark files and the Snakemake log make one case for each kind of resource suggestion.
With --empty, only the configuration is written: no report may fail on a project that hasn't run.
With --broken, some tools get files in an unexpected format: they may only cost those tools their sections.
"""
import gzip
import io
import json
import shutil
import sys
import tarfile
import zipfile
from pathlib import Path

LIBS = ["S1.lib1", "S2.lib1", "S3.lib1", "S4.lib1"]
ASSEMBLIES = {"asm1": LIBS[:2], "asm2": LIBS[2:]}
HOSTS = ["cow", "phix"]
RAW_PAIRS = dict(zip(LIBS, [1000000, 1200000, 800000, 300000]))
BENCH_HEADER = "s\th:m:s\tmax_rss\tmax_vms\tmax_uss\tmax_pss\tio_in\tio_out\tmean_load\tcpu_time\n"


def write(root, relative, text):
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


def write_gz(root, relative, text):
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(path, "wt") as handle:
        handle.write(text)


def fasta(names, length=3000):
    unit = "ACGT" * (length // 4)
    return "".join(f">{name} description\n{unit[:60]}\n{unit[60:]}\n" for name in names)


def tsv(rows):
    return "".join("\t".join(str(field) for field in row) + "\n" for row in rows)


# ---- Configuration ----
def configuration(root, pipeline):
    (root / "config").mkdir(parents=True)
    shutil.copy(pipeline / "config" / "params.yaml", root / "config" / "params.yaml")
    shutil.copy(pipeline / "config" / ".docker.yml", root / "config" / ".docker.yml")
    write(root, "config/config.yaml", """\
features-file: "config/features.yaml"
params-file: "config/params.yaml"
docker-file: "config/.docker.yml"
sample-file: "config/samples.tsv"
assembler: "metaspades"
resource_sets:
  small: {runtime: 300, mem_mb: 16000, cpus: 1, partition: "small", nvme: ""}
  medium: {runtime: 4000, mem_mb: 160000, cpus: 10, partition: "small", nvme: ""}
  medium_nvme: {runtime: 4000, mem_mb: 160000, cpus: 10, partition: "small", nvme: "nvme:10"}
  large: {runtime: 4000, mem_mb: 320000, cpus: 20, partition: "small", nvme: ""}
""")
    write(root, "config/escalation.yaml", """\
assemble__retried: medium, large
assemble__oversized: large
assemble__near_memory: medium
assemble__near_time: small, medium
assemble__not_measured: small
assemble__fits: medium
assemble__on_shm: large
assemble__on_nvme: medium_nvme
assemble__no_log: large
""")
    write(root, "config/features.yaml", """\
hosts:
  cow: resources/reference/cow.fa.gz
  phix: resources/reference/phix.fa.gz
magscot:
  pfam_hmm: resources/MAGScoT/pfam.hmm.gz
databases:
  kraken2:
    standard: resources/databases/kraken2/kraken2_Standard_20240112
  diamond:
    cazy: resources/databases/diamond/CAZyDB.07142024.dmnd
  diamond_contig_protein:
    hyddb: resources/databases/diamond/hyddb.20251125.dmnd
  hmmer:
    fe: resources/databases/hyddb/fe.hmm
    nife: resources/databases/hyddb/nife.hmm
  singlem: resources/databases/singlem/S4.3.0.smpkg.zb
  sylph: resources/databases/sylph/gtdb-r220-c200-dbv1.syldb
  gtdbtk: resources/databases/gtdbtk/release220
""")
    rows = [["sample_id", "library_id", "forward_filename", "reverse_filename", "forward_adapter", "reverse_adapter", "assembly_ids"]]
    for assembly, libraries in ASSEMBLIES.items():
        for library in libraries:
            sample = library.split(".")[0]
            rows.append([sample, "lib1", f"reads/{sample}_1.fq.gz", f"reads/{sample}_2.fq.gz", "AGATCGG", "AGATCGG", assembly])
    write(root, "config/samples.tsv", tsv(rows))


# ---- Reads and preprocess ----
def fastqc_zip(root, relative, reads, gc=44):
    data = f""">>Basic Statistics\tpass
#Measure\tValue
Filename\tx.fq.gz
File type\tConventional base calls
Encoding\tSanger / Illumina 1.9
Total Sequences\t{reads}
Total Bases\t{reads * 100 / 1e6:.1f} Mbp
Sequences flagged as poor quality\t0
Sequence length\t100
%GC\t{gc}
>>END_MODULE
>>Per base sequence quality\tpass
#Base\tMean\tMedian\tLower Quartile\tUpper Quartile\t10th Percentile\t90th Percentile
1\t33.0\t34.0\t31.0\t34.0\t31.0\t34.0
10-14\t36.0\t37.0\t35.0\t38.0\t34.0\t38.0
95-100\t31.0\t33.0\t28.0\t36.0\t20.0\t37.0
>>END_MODULE
>>Per sequence quality scores\tpass
#Quality\tCount
20\t{reads * 0.1}
30\t{reads * 0.3}
36\t{reads * 0.6}
>>END_MODULE
>>Per sequence GC content\tfail
#GC Content\tCount
30\t{reads * 0.2}
44\t{reads * 0.6}
60\t{reads * 0.2}
>>END_MODULE
>>Sequence Length Distribution\tpass
#Length\tCount
100\t{reads}
>>END_MODULE
>>Sequence Duplication Levels\twarn
#Total Deduplicated Percentage\t85.5
#Duplication Level\tPercentage of deduplicated\tPercentage of total
1\t90.0\t80.0
>>END_MODULE
>>Overrepresented sequences\twarn
#Sequence\tCount\tPercentage\tPossible Source
GATCGGAAGAGCACACGTCTGAACTCCAGTCACATCACGATCTCGTATGC\t{int(reads * 0.002)}\t0.2\tTruSeq Adapter
>>END_MODULE
>>Adapter Content\tpass
#Position\tIllumina Universal Adapter\tNextera Transposase Sequence
1\t0.0\t0.0
100\t1.5\t0.1
>>END_MODULE
"""
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    name = path.name.replace(".zip", "")
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr(f"{name}/fastqc_data.txt", data)


def reads_module(root):
    for library in LIBS:
        sample = library.split(".")[0]
        for end in (1, 2):
            write_gz(root, f"reads/{sample}_{end}.fq.gz", "@r\nACGT\n+\nIIII\n")
            fastqc_zip(root, f"results/reads/{library}_{end}_fastqc.zip", RAW_PAIRS[library])
            link = root / f"results/reads/{library}_{end}.fq.gz"
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(root / f"reads/{sample}_{end}.fq.gz")
        write(root, f"results/reads/{library}.log", "")
        write(root, f"results/reads/{library}_1_fastqc_benchmark.tsv", BENCH_HEADER + "60\t0:01:00\t500\t900\t480\t490\t1\t1\t90\t55\n")


def reference_module(root):
    write(root, "results/reference/hosts/cow.fa.gz", "x" * 1000)
    write(root, "results/reference/hosts/cow.fa.gz.fai", "chr1\t1000000\t6\t60\t61\nchr2\t500000\t10\t60\t61\n")
    write(root, "results/reference/hosts/phix.fa.gz", "x" * 100)
    write(root, "results/reference/hosts/phix.fa.gz.fai", "phix\t5386\t6\t60\t61\n")
    write(root, "results/reference/hosts/benchmark/cow.tsv", BENCH_HEADER + "30\t0:00:30\t100\t200\t90\t95\t1\t1\t80\t25\n")


def preprocess_module(root):
    """After fastp 90% of pairs are left; cow takes 10% of those and phix 1 pair in 100 of the rest."""
    for library in LIBS:
        raw = RAW_PAIRS[library]
        kept = int(raw * 0.9)
        curve = [30.0 + i / 10 for i in range(100)]
        report = {
            "summary": {
                "before_filtering": {"total_reads": raw * 2, "total_bases": raw * 200, "q20_rate": 0.95, "q30_rate": 0.90, "read1_mean_length": 100, "gc_content": 0.45},
                "after_filtering": {"total_reads": kept * 2, "total_bases": kept * 190, "q20_rate": 0.99, "q30_rate": 0.96, "read1_mean_length": 95, "gc_content": 0.44},
            },
            "filtering_result": {"passed_filter_reads": kept * 2, "low_quality_reads": raw // 10, "too_many_N_reads": raw // 20, "too_short_reads": raw // 20, "too_long_reads": 0},
            "duplication": {"rate": 0.02},
            "insert_size": {"peak": 170, "unknown": 10, "histogram": [0, 1, 5, 20, 5, 1]},
            "adapter_cutting": {"adapter_trimmed_reads": raw // 50, "adapter_trimmed_bases": raw, "read1_adapter_sequence": "AGATCGG", "read2_adapter_sequence": "AGATCGG",
                                "read1_adapter_counts": {"AGATCGG": 10, "AGATCGT": 5, "others": 1}, "read2_adapter_counts": {"AGATCGG": 8, "others": 2}},
            "read1_before_filtering": {"quality_curves": {"mean": curve}},
            "read1_after_filtering": {"quality_curves": {"mean": curve}},
            "read2_before_filtering": {"quality_curves": {"mean": curve}},
            "read2_after_filtering": {"quality_curves": {"mean": curve}},
            "command": "fastp --in1 a --in2 b --length_required 25 --trim_poly_g",
        }
        write(root, f"results/preprocess/fastp/{library}_fastp.json", json.dumps(report))
        write_gz(root, f"results/preprocess/fastp/{library}_1.fq.gz", "@r\nACGT\n+\nIIII\n")
        fastqc_zip(root, f"results/preprocess/fastp/{library}_1_fastqc.zip", kept)
        fastqc_zip(root, f"results/preprocess/fastp/{library}_2_fastqc.zip", kept)
        write(root, f"results/preprocess/fastp/benchmark/{library}.tsv", BENCH_HEADER + "120\t0:02:00\t2000\t4000\t1900\t1950\t10\t10\t400\t480\n")

        pairs = kept
        for host, removed_share in zip(HOSTS, (0.10, 0.01)):
            removed = int(pairs * removed_share)
            # Half of the removed pairs have both reads mapped, the others one read
            both_pairs = removed // 2
            one_read = removed - both_pairs
            mapped = both_pairs * 2 + one_read
            write(root, f"results/preprocess/bowtie2/{host}/{library}.stats.txt",
                  f"SN\traw total sequences:\t{pairs * 2}\t# comment\nSN\treads mapped:\t{mapped}\nSN\treads mapped and paired:\t{both_pairs * 2}\t# comment\n")
            write(root, f"results/preprocess/bowtie2/{host}/{library}.flagstats.txt", f"{pairs * 2} + 0 in total (QC-passed reads + QC-failed reads)\n{mapped} + 0 mapped (1.00% : N/A)\n")
            write(root, f"results/preprocess/quantification/{host}/{library}.chr_alignment_counts.tsv", f"chr1 {mapped}\n* 0\n")
            fastqc_zip(root, f"results/preprocess/bowtie2/non{host}/{library}_1_fastqc.zip", pairs - removed)
            fastqc_zip(root, f"results/preprocess/bowtie2/non{host}/{library}_2_fastqc.zip", pairs - removed)
            pairs -= removed


# ---- Read annotation ----
def read_annotate_module(root):
    for i, library in enumerate(LIBS):
        write(root, f"results/read_annotate/kraken2/standard/{library}.report", tsv([
            [20.0, 200, 200, "U", 0, "unclassified"],
            [80.0, 800, 0, "R", 1, "root"],
            [80.0, 800, 0, "D", 2, "  Bacteria"],
            [60.0, 600, 0, "P", 200, "    Bacillota"],
            [20.0, 200, 0, "P", 201, "    Bacteroidota & friends_100%"],
            [60.0, 600, 100, "G", 300, "      Clostridium"],
            [20.0, 200, 100, "G", 301, "      Prevotella α"],
            [50.0, 500, 500, "S", 400, "        Clostridium sp."],
            [10.0, 100, 100, "S", 401, "        Prevotella sp."],
        ]))
        write(root, f"results/read_annotate/krona/standard/{library}.html", "<html></html>")
        write(root, f"results/read_annotate/nonpareil/{library}.npo", "# @impl: Nonpareil\n0\t0\t0\t0\t0\t0\n1000\t0.1\t0.01\t0.1\t0.1\t0.1\n100000\t0.4\t0.02\t0.4\t0.4\t0.4\n")
        write(root, f"results/read_annotate/humann/{library}_genefamilies.tsv", tsv([
            ["# Gene Family", f"{library}_Abundance-RPKs"], ["UNMAPPED", 500.0], ["UniRef90_A", 300.0], ["UniRef90_A|g__X.s__Y", 300.0], ["UniRef90_B", 200.0],
        ]))
        write(root, f"results/read_annotate/sylph/{library}.profiling.tsv", tsv([
            ["Sample_file", "Genome_file", "Taxonomic_abundance", "Sequence_abundance", "Adjusted_ANI", "Eff_cov", "Eff_lambda", "Contig_name"],
            # As in real output, Eff_lambda is HIGH at high coverage, so that it isn't a number in each library
            [f"{library}_1", "g1.fna.gz", 70.0, 30.0, 98.5, 2.0, "HIGH" if library == LIBS[0] else 2.0, "Genome one"],
            [f"{library}_1", "g2.fna.gz", 30.0, 10.0, 96.0, 1.0, 1.0, "Genome two"],
        ]))
        prefix = library.replace(".", "_")
        write(root, f"results/read_annotate/phyloflash/{prefix}.phyloFlash.html", "<html></html>")
        # The real archive has about 25 more files. A real report has a command with commas and lines after these.
        report = "".join(f"{key},{value}\n" for key, value in [
            ("version", "phyloFlash v3.4.2"), ("library name", prefix), ("input reads", 1000), ("input read segments", 2000),
            ("mapped SSU reads", 20), ("mapped SSU read segments", 30), ("mapping ratio", "2.000"), ("NTUs observed once", 1),
            ("NTUs observed twice", 0), ("NTUs observed three or more times", 2), ("NTU Chao1 richness estimate", "2.000"),
            ("program command", "phyloFlash.pl -lib a,b"),
        ])
        abundance = "Bacteria;Bacteroidota;Bacteroidia;Bacteroidales,15\nEukaryota;SAR;Alveolata;Ciliophora,4\nBacteria;Bacillota;Bacilli;RF39,1\n"
        archive = root / f"results/read_annotate/phyloflash/{prefix}.phyloFlash.tar.gz"
        with tarfile.open(archive, "w:gz") as handle:
            for name, content in ((f"{prefix}.phyloFlash.report.csv", report), (f"{prefix}.phyloFlash.NTUabundance.csv", abundance)):
                info = tarfile.TarInfo(name)
                info.size = len(content.encode())
                handle.addfile(info, io.BytesIO(content.encode()))
    write(root, "results/read_annotate/nonpareil/nonpareil.tsv", tsv(
        [["sample_id", "kappa", "C", "LR", "modelR", "LRstar", "diversity"]]
        + [[library, 0.1, 0.5, 1e8, 0.99, 1e9, 20.0] for library in LIBS[:3]]
        + [[LIBS[3], 0.05, 0.1, 1e7, "NA", "NA", 0.0]]
    ))
    write(root, "results/read_annotate/singlem/singlem.tsv", tsv(
        [["sample", "coverage", "taxonomy"]]
        + [[library, cov, tax] for library in LIBS for cov, tax in [(10.0, "Root; d__Bacteria"), (6.0, "Root; d__Bacteria; p__Bacillota"), (4.0, "Root; d__Bacteria; p__Bacteroidota")]]
    ))
    write(root, "results/read_annotate/singlem/microbial_fraction.tsv", tsv(
        [["sample", "bacterial_archaeal_bases", "metagenome_size", "read_fraction", "warning"]] + [[library, 1000, 2000, "50.0%", ""] for library in LIBS]
    ))
    write(root, "results/read_annotate/metaphlan/metaphlan_profiled.tsv", "#mpa_vJan21\n" + tsv(
        [["clade_name"] + LIBS,
         ["k__Bacteria"] + [100.0] * 4,
         ["k__Bacteria|p__B|c__C|o__O|f__F|g__G|s__Species_one"] + [70.0] * 4,
         ["k__Bacteria|p__B|c__C|o__O|f__F|g__G|s__Species_two"] + [30.0, 30.0, 30.0, 0.0],
         ["k__Bacteria|p__B|c__C|o__O|f__F|g__G|s__Species_two|t__T1"] + [30.0, 30.0, 30.0, 0.0]]
    ))
    write(root, "results/read_annotate/diamond/cazy/summary_a.tsv", tsv(
        [["Feature"] + [f"{library}_R1" for library in LIBS], ["GH1"] + [5, 6, 7, 8], ["GH2"] + [1, 0, 0, 2]]
    ))
    # One protein of S1 and two of S4 have both labels, which share such a hit out
    write(root, "results/read_annotate/diamond/cazy/summary_b.tsv", tsv(
        [["Feature"] + [f"{library}_R1" for library in LIBS], ["GH1"] + [4.5, 6, 7, 7], ["GH2"] + [0.5, 0, 0, 1]]
    ))
    columns = [f"{library}_{end}" for library in LIBS for end in (1, 2)]
    write(root, "results/read_annotate/ncyc/ncyc_results.tsv", "#random sampling: 1000\n" + tsv(
        [["Gene"] + columns, ["glnA"] + [10] * 8, ["nirK"] + [1, 2, 0, 0, 1, 1, 0, 0]]
    ))
    write(root, "results/read_annotate/nonpareil/benchmark/S1.lib1.tsv", BENCH_HEADER + "20\t0:00:20\t100\t200\t90\t95\t1\t1\t80\t18\n")


# ---- Assembly ----
def assemble_module(root):
    for assembly, libraries in ASSEMBLIES.items():
        names = [f"{assembly}:bin_NA@contig_{i:08d}" for i in range(1, 11)]
        write_gz(root, f"results/assemble/metaspades/{assembly}.fa.gz", fasta(names))
        for library in libraries:
            write(root, f"results/assemble/bowtie2/{assembly}.{library}.log",
                  f"900 reads; of these:\n  900 (100.00%) were paired; of these:\n75.50% overall alignment rate\n")
        for binner, bins in (("metabat2", 2), ("maxbin2", 3), ("concoct", 4)):
            for b in range(bins):
                write_gz(root, f"results/assemble/{binner}/{assembly}/bin.{b}.fa.gz", fasta(names[:2]))
        refined = [["binnew", "contig"]] + [[f"results/assemble/magscot/{assembly}/magscot_cleanbin_00000{1 + i % 2}", name] for i, name in enumerate(names[:6])]
        write(root, f"results/assemble/magscot/{assembly}/magscot.refined.contig_to_bin.out", tsv(refined))
        write(root, f"results/assemble/magscot/{assembly}/magscot.refined.out", tsv([
            ["bin", "set", "uniqueSCGs", "multipleSCGs", "sumSCGs", "n_markers", "n_contigs", "Completeness", "additionalSCGs", "Contamination", "MultiContam", "Contamination_Score", "score", "bintool", "refined_id"],
            ["bin_1", "gtdb_rel207_bac120", 100, 2, 102, 120, 3, 0.9, 0, 0.02, 0, 0.01, 0.88, "metabat2", "cleanbin_1"],
            ["bin_2", "gtdb_rel207_bac120", 60, 2, 62, 120, 3, 0.6, 0, 0.05, 0, 0.02, 0.55, "concoct", "cleanbin_2"],
        ]))
        write_gz(root, f"results/assemble/drep/separated_bins/{assembly}:bin_000001.fa", "")
    (root / "results/assemble/drep/separated_bins").mkdir(parents=True, exist_ok=True)
    for path in list((root / "results/assemble/drep/separated_bins").iterdir()):
        path.unlink()
    for name in ("asm1:bin_000001.fa", "asm1:bin_000002.fa", "asm2:bin_000001.fa", "asm2:bin_000002.fa"):
        write(root, f"results/assemble/drep/separated_bins/{name}", fasta(["x"]))
    write_gz(root, "results/assemble/drep/dereplicated_genomes/asm1:bin_000001.fa.gz", fasta(["c1"]))
    write_gz(root, "results/assemble/drep/dereplicated_genomes/asm2:bin_000001.fa.gz", fasta(["c2"]))
    write(root, "results/assemble/drep/dereplicated_genomes.fa.gz.fai", "c1\t3000\t1\t60\t61\nc2\t2000\t1\t60\t61\nc3\t1000\t1\t60\t61\n")
    tables = {
        "genomeInformation.csv": "genome,completeness,contamination,strain_heterogeneity,length,N50,centrality\nasm1:bin_000001.fa,90,2,0,3000000,5000,0.9\nasm2:bin_000001.fa,80,3,0,2000000,4000,0.8\n",
        "Cdb.csv": "genome,secondary_cluster,threshold,cluster_method,comparison_algorithm,primary_cluster\nasm1:bin_000001.fa,1_1,0.05,average,fastANI,1\nasm2:bin_000001.fa,2_1,0.05,average,fastANI,2\n",
        "Wdb.csv": "genome,cluster,score\nasm1:bin_000001.fa,1_1,80\nasm2:bin_000001.fa,2_1,70\n",
    }
    archive = root / "results/assemble/drep/data_tables.tar.gz"
    with tarfile.open(archive, "w:gz") as tar:
        for name, text in tables.items():
            data = text.encode()
            info = tarfile.TarInfo(f"data_tables/{name}")
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    resource_cases(root)


def resource_cases(root):
    """(rule, wall s, peak MB, CPU s): one kind of suggestion each. Requested values come from the log."""
    cases = {
        # Failed on medium, finished on large
        "retried": (1000, 200000, 15000, 2, 320000, 20, 4000),
        # Large, but 2 GB, 1.5 cores, 10 minutes: fits medium
        "oversized": (600, 2000, 900, 1, 320000, 20, 4000),
        # 150 of 160 GB
        "near_memory": (6000, 150000, 50000, 1, 160000, 10, 4000),
        # 290 of 300 minutes on small
        "near_time": (17400, 1000, 17000, 1, 16000, 1, 300),
        # Memory wasn't measured
        "not_measured": (100, 0, 0, 1, 16000, 1, 300),
        # 90 of 160 GB and 9 of 10 cores
        "fits": (6000, 92000, 54000, 1, 160000, 10, 4000),
        # 2 GB, but a database in /dev/shm: memory stays
        "on_shm": (6000, 2000, 6000, 1, 320000, 20, 4000),
        # 2 GB, but the set has local disk, which small has not
        "on_nvme": (600, 2000, 600, 1, 160000, 10, 4000),
    }
    blocks = ["Building DAG of jobs...\n"]
    for jobid, (name, (wall, peak, cpu, attempt, mem, cpus, runtime)) in enumerate(cases.items(), start=1):
        benchmark = f"results/assemble/cases/{name}/benchmark/job.tsv"
        write(root, benchmark, BENCH_HEADER + f"{wall}\t0:00:00\t{peak}\t{peak}\t{peak}\t{peak}\t1\t1\t100\t{cpu}\n")
        if attempt > 1:
            blocks.append(f"[Wed Nov  4 12:00:00 2026]\nrule assemble__{name}:\n    jobid: {jobid}\n    benchmark: {benchmark}\n    threads: 10\n"
                          f"    resources: tmpdir=/tmp, runtime=4000, mem_mb=160000, mem_mib=152588, cpus_per_task=10, slurm_partition=small, gres=nvme:0, attempt=1\n"
                          f"Error in rule assemble__{name}:\n    message: killed\n    jobid: {jobid}\nTrying to restart job {jobid}.\n")
        blocks.append(f"[Wed Nov  4 12:00:00 2026]\nrule assemble__{name}:\n    output: results/assemble/cases/{name}/out\n    jobid: {jobid}\n    benchmark: {benchmark}\n    wildcards: x=1\n"
                      f"    threads: {cpus}\n    resources: tmpdir=/tmp, runtime={runtime}, mem_mb={mem}, mem_mib=1, cpus_per_task={cpus}, slurm_partition=small, gres=nvme:0, attempt={attempt}\n"
                      f"Finished jobid: {jobid} (Rule: assemble__{name})\n")
    write(root, ".snakemake/log/2026-11-04T120000.000000.snakemake.log", "".join(blocks))
    # This one isn't in the log, so its requested values come from the configuration
    write(root, "results/assemble/cases/no_log/benchmark/job.tsv", BENCH_HEADER + "600\t0:10:00\t2000\t2000\t2000\t2000\t1\t1\t100\t900\n")


# ---- Quantification ----
def quantify_module(root):
    genomes = [f"genome_{i}" for i in range(1, 5)]
    for method, values in (
        ("count", [[1000, 2000, 0, 50], [500, 10, 300, 40], [20, 30, 40, 50], [0, 0, 5, 700]]),
        ("tpm", [[500000, 700000, 0, 50000], [300000, 10000, 500000, 40000], [200000, 290000, 480000, 10000], [0, 0, 20000, 900000]]),
        ("covered_bases", [[90000, 95000, 0, 3000], [80000, 500, 60000, 2000], [1000, 2000, 3000, 4000], [0, 0, 300, 90000]]),
        ("length", [[100000] * 4, [100000] * 4, [100000] * 4, [100000] * 4]),
    ):
        write(root, f"results/quantify/coverm/genome.{method}.tsv", tsv([["sequence_id"] + LIBS] + [[g] + v for g, v in zip(genomes, values)]))
        write(root, f"results/quantify/coverm/contig.{method}.tsv", tsv([["sequence_id"] + LIBS] + [[f"{g}@contig_1"] + v for g, v in zip(genomes, values)]))
    for library in LIBS:
        write(root, f"results/quantify/bowtie2/{library}.flagstats.txt", "1000 + 0 in total (QC-passed reads + QC-failed reads)\n1000 + 0 primary\n250 + 0 mapped (25.00% : N/A)\n250 + 0 primary mapped (25.00% : N/A)\n200 + 0 properly paired (20.00% : N/A)\n")


# ---- Annotation of genomes and contigs ----
def mag_annotate_module(root):
    write(root, "results/mag_annotate/checkm2/quality_report.tsv", tsv([
        ["Name", "Completeness", "Contamination", "Completeness_Model_Used", "Translation_Table_Used", "Coding_Density", "Contig_N50", "Average_Gene_Length", "Genome_Size", "GC_Content", "Total_Coding_Sequences", "Additional_Notes"],
        ["genome_1", 95.0, 1.0, "Neural", 11, 0.9, 50000, 300, 3000000, 0.45, 2900, "None"],
        ["genome_2", 70.0, 4.0, "Neural", 11, 0.9, 10000, 300, 2000000, 0.5, 1900, "None"],
        ["genome_3", 40.0, 2.0, "Neural", 11, 0.9, 3000, 300, 1000000, 0.4, 900, "None"],
        ["genome_4", 92.0, 12.0, "Neural", 11, 0.9, 8000, 300, 2500000, 0.55, 2400, "None"],
    ]))
    tax = "d__Bacteria;p__Bacillota;c__Clostridia;o__Lachnospirales;f__Lachnospiraceae;g__Blautia;s__"
    write(root, "results/mag_annotate/gtdbtk/gtdbtk.summary.tsv", tsv([
        ["user_genome", "classification", "closest_genome_ani", "note"],
        ["genome_1", tax + "Blautia wexlerae", 98.0, ""], ["genome_2", tax, "N/A", ""],
        ["genome_3", "d__Bacteria;p__Bacteroidota;c__Bacteroidia;o__O;f__F;g__;s__", "N/A", ""], ["genome_4", tax + "Blautia sp", 97.0, ""],
    ]))
    write(root, "results/mag_annotate/quast/report.tsv", tsv([["Assembly", "dereplicated_genomes"], ["# contigs", 554], ["Total length", 1647187], ["N50", 3208]]))
    write(root, "results/mag_annotate/dram/genome_stats.tsv", tsv([
        ["genome", "number of scaffolds", "taxonomy", "completeness score", "contamination score", "5S rRNA", "16S rRNA", "23S rRNA", "tRNA count", "assembly quality"],
        ["genome_1", 10, tax, 95, 1, 1, 1, 1, 18, "high"],
    ]))
    write(root, "results/mag_annotate/dram/product.tsv", tsv([["genome", "Glycolysis", "Methanogenesis"], ["genome_1", 0.9, 0.0], ["genome_2", 0.8, 0.1]]))
    write(root, "results/mag_annotate/bakta/bakta.tsv", "# Annotated with Bakta\n# Software: v1.9\n" + tsv([
        ["#Sequence Id", "Type", "Start", "Stop", "Strand", "Locus Tag", "Gene", "Product", "DbXrefs"],
        ["c1", "cds", 1, 100, "+", "L1", "abc", "hypothetical protein", ""], ["c1", "cds", 200, 300, "+", "L2", "def", "kinase", ""], ["c1", "tRNA", 400, 480, "+", "L3", "", "tRNA-Ala", ""],
    ]))
    write(root, "results/mag_annotate/camper/annotations.tsv", tsv([["", "fasta", "CAMPER_hits", "CAMPER_definition"], ["g1", "x", "K1", "Function A"], ["g2", "x", "", ""], ["g3", "x", "K2", "Function A"]]))
    write(root, "results/mag_annotate/proteinortho/proteinortho.proteinortho.tsv", tsv([["# Species", "Genes", "Alg.-Conn.", "a.faa", "b.faa"], [2, 2, 1, "x", "y"], [2, 2, 1, "x", "y"], [1, 3, 0.5, "x,y,z", "*"]]))
    write(root, "results/mag_annotate/eggnog/out.emapper.seed_orthologs", "#comment\ng1\tx\t1e-5\t100\ng2\ty\t1e-5\t100\n")
    # As in the rule, with --no_file_comments, so it has no header. Column 7 is the COG category, and column 12 the KEGG ortholog.
    write(root, "results/mag_annotate/eggnog/out.emapper.annotations", tsv([
        ["g1", "x", "1e-5", 100, "OG", "lvl", "EK", "desc", "name", "-", "-", "ko:K00001"] + ["-"] * 9,
        ["g2", "y", "1e-5", 100, "OG", "lvl", "E", "desc", "name", "-", "-", "-"] + ["-"] * 9,
        ["g3", "z", "1e-5", 100, "OG", "lvl", "-", "desc", "name", "-", "-", "-"] + ["-"] * 9,
    ]))
    write(root, "results/mag_annotate/phylophlan/SGB/SGB.tsv", "#header\ngenome_1\tx\n")


def contig_annotate_module(root):
    for assembly, libraries in ASSEMBLIES.items():
        write(root, f"results/contig_annotate/prodigal/{assembly}/{assembly}.prodigal_plain.gtf", tsv([
            ["c1", "Prodigal_v2.6.3", "CDS", 1, 300, 1.0, "+", 0, "ID=1_1;partial=00;gc_cont=0.500;"],
            ["c1", "Prodigal_v2.6.3", "CDS", 400, 1000, 1.0, "+", 0, "ID=1_2;partial=10;gc_cont=0.400;"],
            ["c2", "Prodigal_v2.6.3", "CDS", 1, 600, 1.0, "-", 0, "ID=2_1;partial=00;gc_cont=0.600;"],
        ]))
        write(root, f"results/contig_annotate/prodigal/{assembly}/{assembly}.prodigal.gtf", "# comment\n# comment\nc1\tx\n")
        for library in libraries:
            write(root, f"results/contig_annotate/featurecounts/{assembly}/{assembly}_{library}.prodigal_fc.txt.summary", tsv([
                ["Status", "x.bam"], ["Assigned", 600], ["Unassigned_Unmapped", 300], ["Unassigned_NoFeatures", 80], ["Unassigned_Ambiguity", 20], ["Unassigned_MultiMapping", 0],
            ]))
        # The rule writes no header (--no_file_comments), but a file from elsewhere can have one
        header = [["#query", "seed_ortholog", "evalue", "score", "eggNOG_OGs", "max_annot_lvl", "COG_category", "Description", "Preferred_name", "GOs", "EC", "KEGG_ko"]] if assembly == "asm2" else []
        write(root, f"results/contig_annotate/eggnog/{assembly}/eggnog_output.emapper.annotations", tsv(header + [
            ["g1", "x", 1e-5, 100, "y", "z", "K", "Transcription", "-", "-", "-", "ko:K1"], ["g2", "x", 1e-5, 100, "y", "z", "CE", "Energy", "-", "-", "-", "-"], ["g3", "x", 1e-5, 100, "y", "z", "-", "None", "-", "-", "-", "-"],
        ]))
        write_gz(root, f"results/contig_annotate/eggnog7/{assembly}/{assembly}.eggnog.tsv.gz", "a\tb\n")
        write(root, f"results/contig_annotate/diamond/hyddb/{assembly}.out", "g1\tx\t90\ng1\ty\t80\ng2\tx\t70\n")
        for db, score in (("fe", 60.0), ("nife", 20.0)):
            write(root, f"results/contig_annotate/hmmer/{db}/{assembly}.tblout.tsv", f"# comment\ng1 - hmm - 1e-20 {score} 0.1 1e-20 {score} 0.1 1 1 0 0 1 1 1 1 -\n")
        write(root, f"results/contig_annotate/camper/{assembly}/annotations.tsv", tsv([["", "fasta", "CAMPER_hits"], ["g1", "x", "K1"], ["g2", "x", ""]]))
    write(root, "results/contig_annotate/ncyc/ncyc_results.tsv", "#random sampling: 100\n" + tsv([["Gene", "asm1.prodigal", "asm2.prodigal"], ["glnA", 1, 2]]))


def eukaryote_module(root):
    for assembly in ASSEMBLIES:
        names = [f"{assembly}:bin_NA@contig_{i:08d}" for i in range(1, 11)]
        classes = ["bacteria"] * 6 + ["eukarya"] * 3 + ["unknown"]
        write(root, f"results/eukaryote/tiara/{assembly}.tsv", tsv(
            [["sequence_id", "class_fst_stage", "class_snd_stage", "org", "bac", "arc", "euk", "unk1", "pla", "unk2", "mit"]]
            + [[name, c, "n/a", 0, 0, 0, 0, 0, "n/a", "n/a", "n/a"] for name, c in zip(names, classes)]
        ))
        write(root, f"results/eukaryote/4cac/{assembly}.tsv", tsv(
            [["contig_id", "node_id", "class", "phage", "plasmid", "prokarya", "eukarya"]]
            + [[name, f"NODE_{i}", "eukarya" if i < 2 else "prokarya", 0, 0, 0, 0] for i, name in enumerate(names)]
        ))
        write(root, f"results/eukaryote/remag/{assembly}.tsv", tsv(
            [["contig_id", "length", "prediction", "eukaryote_prob", "confidence", "num_windows", "resampled"]]
            + [[name, 3000, "eukaryote" if i < 3 else "prokaryote", 0.9, 0.9, 1, "False"] for i, name in enumerate(names)]
        ))
        write_gz(root, f"results/eukaryote/remag/{assembly}/bins/bin_1.fa.gz", fasta(names[:3]))


def break_outputs(root):
    """Files that a new version of a tool could write, with other columns or other fields than the reports expect"""
    write(root, f"results/read_annotate/sylph/{LIBS[0]}.profiling.tsv", "Sample_file\tGenome\nS1\tg1\n")
    write(root, "results/mag_annotate/checkm2/quality_report.tsv", "Genome\tScore\ng1\t90\n")
    write(root, "results/eukaryote/tiara/asm1.tsv", "contig\tlabel\nc1\tbacteria\n")
    write(root, "results/contig_annotate/hmmer/fe/asm1.tblout.tsv", "not a table of HMMER\n")


def main():
    root = Path(sys.argv[1])
    pipeline = Path(sys.argv[2])
    configuration(root, pipeline)
    if "--empty" in sys.argv:
        return
    reads_module(root)
    reference_module(root)
    preprocess_module(root)
    read_annotate_module(root)
    assemble_module(root)
    quantify_module(root)
    mag_annotate_module(root)
    contig_annotate_module(root)
    eukaryote_module(root)
    if "--broken" in sys.argv:
        break_outputs(root)


if __name__ == "__main__":
    main()
