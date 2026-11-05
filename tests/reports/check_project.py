#!/usr/bin/env python3
"""Compare the tables of the module reports with what a project's files say.

Usage: check_project.py synthetic <project>
       check_project.py broken <project>
       check_project.py empty <project>
       check_project.py real <project> <expected_real.tsv>
"""
import csv
import sys
from pathlib import Path

MODULES = ["reads", "reference", "preprocess", "read_annotate", "assemble", "quantify", "mag_annotate", "contig_annotate", "eukaryote"]
failures = []


def check(label, actual, expected):
    if isinstance(expected, float) or isinstance(actual, float):
        same = actual not in (None, "") and abs(float(actual) - float(expected)) <= abs(float(expected)) * 0.001 + 1e-9
    else:
        same = str(actual) == str(expected)
    print(("ok  " if same else "FAIL"), label, "=", actual, "" if same else f"(expected {expected})")
    if not same:
        failures.append(label)


def table(project, module, name):
    path = Path(project) / "Rreports" / module / "tables" / f"{name}.tsv"
    with open(path) as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def row(rows, key, value):
    return next(r for r in rows if r[key] == value)


def check_reports_exist(project):
    for module in MODULES:
        pdf = Path(project) / "Rreports" / f"{module}.pdf"
        check(f"{module}: PDF exists", pdf.exists() and pdf.stat().st_size > 1000, True)
        errors = Path(project) / "Rreports" / module / "section_errors.txt"
        text = errors.read_text().strip() if errors.exists() else "no file"
        check(f"{module}: no section failed", text, "")


def synthetic(project):
    check_reports_exist(project)

    reads = table(project, "reads", "reads_per_library")
    check("reads: read pairs of S2", float(row(reads, "library", "S2.lib1")["read_pairs"]), 1200000.0)
    check("reads: libraries", len(reads), 4)
    check("reads: mean quality", float(row(reads, "library", "S1.lib1")["mean_quality"]), 2 + 0.1 * 20 + 0.3 * 30 + 0.6 * 36 - 2)
    check("reads: Q30 share", float(row(reads, "library", "S1.lib1")["reads_q30_pct"]), 90.0)

    hosts = table(project, "reference", "hosts")
    check("reference: length of the cow", float(row(hosts, "host", "cow")["total_bp"]), 1500000.0)
    check("reference: sequences of phix", row(hosts, "host", "phix")["sequences"], 1)

    steps = table(project, "preprocess", "read_pairs_per_step")
    s1 = row(steps, "library", "S1.lib1")
    check("preprocess: after fastp", float(s1["after_fastp"]), 900000.0)
    check("preprocess: removed by the cow", float(s1["removed_cow"]), 90000.0)
    check("preprocess: removed by phix", float(s1["removed_phix"]), 8100.0)
    check("preprocess: clean pairs", float(s1["clean_pairs"]), 801900.0)
    adapters = table(project, "preprocess", "adapter_trimming")
    check("preprocess: trimmed bases", float(row(adapters, "library", "S1.lib1")["trimmed_bases"]), 1000000.0)

    kraken = table(project, "read_annotate", "kraken2_summary")
    # The direct reads of all taxa in the made-up report
    check("read_annotate: classified share", float(row(kraken, "library", "S1.lib1")["classified_pct"]), 100 * 800 / 1000)
    nonpareil = table(project, "read_annotate", "nonpareil")
    check("read_annotate: no model stays empty", row(nonpareil, "sample_id", "S4.lib1")["LRstar"], "")
    humann = table(project, "read_annotate", "humann_per_library")
    check("read_annotate: unmapped share counts unstratified rows only", float(humann[0]["unmapped_pct"]), 50.0)
    ncyc = table(project, "read_annotate", "ncyc_per_library")
    check("read_annotate: hits add both read files", row(ncyc, "library", "S1.lib1")["hits"], 23)
    check("read_annotate: genes with hits", row(ncyc, "library", "S1.lib1")["genes"], 2)
    diamond = table(project, "read_annotate", "diamond_cazy_per_file")
    check("read_annotate: DIAMOND counts a read with two labels once", row(diamond, "file", "S1.lib1_R1")["hits"], 5.0)
    check("read_annotate: DIAMOND labels", row(diamond, "file", "S1.lib1_R1")["labels"], 6.0)
    phyloflash = table(project, "read_annotate", "phyloflash_per_library")
    check("read_annotate: phyloFlash SSU read pairs", row(phyloflash, "library", "S1.lib1")["ssu_pairs"], 20)
    check("read_annotate: phyloFlash NTUs of all three classes", row(phyloflash, "library", "S1.lib1")["ntus"], 3)
    taxa = table(project, "read_annotate", "phyloflash_taxa")
    check("read_annotate: phyloFlash reads per taxon", row(taxa, "taxon", "Eukaryota;SAR;Alveolata;Ciliophora")["S2.lib1"], 4)
    sylph = table(project, "read_annotate", "sylph_per_library")
    check("read_annotate: sylph with HIGH in one library", row(sylph, "library", "S2.lib1")["genomes"], 2)
    check("read_annotate: sylph median coverage", row(sylph, "library", "S1.lib1")["median_coverage"], 1.5)
    check("read_annotate: DIAMOND features", row(diamond, "file", "S2.lib1_R1")["features"], 1)

    stats = table(project, "assemble", "assembly_statistics")
    check("assemble: contigs", row(stats, "assembly_id", "asm1")["contigs"], 10)
    bins = table(project, "assemble", "bins_per_assembly")
    asm1 = row(bins, "assembly_id", "asm1")
    check("assemble: the header of MAGScoT's file isn't a bin", asm1["magscot"], 2)
    check("assemble: MetaBAT2 bins", asm1["metabat2"], 2)
    check("assemble: binned share", float(asm1["binned_pct"]), 60.0)
    mapping = table(project, "assemble", "mapping_rates")
    check("assemble: alignment rate", float(mapping[0]["overall_pct"]), 75.5)
    catalogue = table(project, "assemble", "catalogue")
    check("assemble: length of the catalogue", float(catalogue[0]["total_bp"]), 6000.0)

    genomes = table(project, "quantify", "genomes")
    check("quantify: reads on a genome", float(row(genomes, "genome", "genome_1")["reads"]), 3050.0)
    check("quantify: libraries with reads", row(genomes, "genome", "genome_1")["libraries_detected"], 3)
    per_library = table(project, "quantify", "mapping_to_catalogue")
    check("quantify: mapped share", float(per_library[0]["mapped_pct"]), 25.0)

    quality = table(project, "mag_annotate", "genome_quality")
    check("mag_annotate: high quality", row(quality, "genome", "genome_1")["quality"], "High")
    check("mag_annotate: medium quality", row(quality, "genome", "genome_2")["quality"], "Medium")
    check("mag_annotate: low, as incomplete", row(quality, "genome", "genome_3")["quality"], "Low")
    check("mag_annotate: low, as contaminated", row(quality, "genome", "genome_4")["quality"], "Low")
    taxa = table(project, "mag_annotate", "taxa_per_rank")
    check("mag_annotate: genomes without a species", row(taxa, "Rank", "Species")["Genomes without a name"], 2)
    bakta = table(project, "mag_annotate", "bakta_features")
    check("mag_annotate: Bakta types", len(bakta), 2)

    genes = table(project, "contig_annotate", "genes_per_assembly")
    check("contig_annotate: genes, without comment lines", row(genes, "assembly_id", "asm1")["genes"], 3)
    counts = table(project, "contig_annotate", "featurecounts")
    check("contig_annotate: assigned reads", counts[0]["assigned"], 600)
    hmmer = table(project, "contig_annotate", "hmmer_hits")
    check("contig_annotate: Fe hit over its threshold", row(hmmer, "database", "fe")["proteins_over_threshold"], 1)
    check("contig_annotate: NiFe hit under its threshold", row(hmmer, "database", "nife")["proteins_over_threshold"], 0)
    eggnog = table(project, "contig_annotate", "eggnog_per_assembly")
    check("contig_annotate: genes with a COG, no header", row(eggnog, "assembly_id", "asm1")["with_cog"], 2)
    check("contig_annotate: genes with a COG, with a header", row(eggnog, "assembly_id", "asm2")["with_cog"], 2)
    check("contig_annotate: genes with a KEGG KO", row(eggnog, "assembly_id", "asm1")["with_kegg"], 1)

    tiara = table(project, "eukaryote", "tiara_classes")
    check("eukaryote: Tiara's eukaryotic contigs", [r for r in tiara if r["class"] == "eukarya"][0]["contigs"], 3)
    check("eukaryote: their bases, from the assembly", float([r for r in tiara if r["class"] == "eukarya"][0]["bases"]), 9000.0)
    check("eukaryote: REMAG's bins", len(table(project, "eukaryote", "remag_bins")), 2)

    # One case per kind of suggestion, see resource_cases() in make_project.py
    rules = table(project, "assemble", "resources_per_rule")

    def case(name):
        return row(rules, "rule", f"assemble__{name}")

    check("resources: retried, action", case("retried")["action"], "start higher")
    check("resources: retried, new line", case("retried")["new_chain"], "large")
    check("resources: retried, requested memory is the attempt that finished", float(case("retried")["req_mem_mb"]), 320000.0)
    check("resources: oversized, action", case("oversized")["action"], "reduce")
    check("resources: oversized, needs 2 cores, so not small", case("oversized")["new_chain"], "medium, large")
    check("resources: oversized, memory use", float(case("oversized")["mem_used_pct"]), 100 * 2000 / 320000)
    check("resources: oversized, cores", float(case("oversized")["cores_mean"]), 1.5)
    check("resources: near the memory limit, action", case("near_memory")["action"], "raise")
    check("resources: near the memory limit, new line", case("near_memory")["new_chain"], "large")
    check("resources: near the time limit, action", case("near_time")["action"], "raise")
    check("resources: not measured, action", case("not_measured")["action"], "not measured")
    check("resources: fits, action", case("fits")["action"], "keep")
    check("resources: database in /dev/shm keeps its memory", case("on_shm")["action"], "keep")
    check("resources: local disk stays", case("on_nvme")["action"], "keep")
    check("resources: without a log, requested comes from the configuration", float(case("no_log")["req_mem_mb"]), 320000.0)
    jobs = table(project, "assemble", "resources_per_job")
    check("resources: without a log, marked as such", row(jobs, "rule", "assemble__no_log")["source"], "configuration")
    check("resources: with a log, marked as such", row(jobs, "rule", "assemble__fits")["source"], "log")

    suggestions = (Path(project) / "Rreports" / "assemble" / "escalation_suggestions.yaml").read_text()
    check("resources: the YAML has the reduction", "assemble__oversized: medium, large  # was: large" in suggestions, True)
    check("resources: the YAML leaves out what stays", "assemble__fits" in suggestions, False)

    data = table(project, "reads", "data_per_folder")
    # 8 FastQC files, 4 logs, 4 benchmarks, and not the 8 links to reads
    check("data: links aren't counted", sum(int(r["files"]) for r in data), 16)
    several = row(table(project, "reads", "resources_per_rule"), "rule", "helpers__fastqc")
    check("resources: a rule with several jobs, jobs", several["jobs"], 4)
    check("resources: a rule with several jobs, memory use", float(several["mem_used_pct"]), 100 * 500 / 16000)
    check("resources: a rule with several jobs, core-hours used", float(several["core_hours_used"]), 4 * 55 / 3600)
    files = table(project, "assemble", "all_files")
    check("data: every file is listed", any(r["file"].endswith("magscot.refined.out") for r in files), True)


def broken(project):
    """An unexpected file costs its tool the section, and nothing else"""
    for module, tool in (("read_annotate", "sylph"), ("mag_annotate", "CheckM2"), ("eukaryote", "Tiara"), ("contig_annotate", "HMMER")):
        pdf = Path(project) / "Rreports" / f"{module}.pdf"
        check(f"{module}: PDF exists with a broken {tool} file", pdf.exists() and pdf.stat().st_size > 1000, True)
        errors = (Path(project) / "Rreports" / module / "section_errors.txt").read_text()
        check(f"{module}: the failure of {tool} is on record", f"{tool}: " in errors, True)
    tables = Path(project) / "Rreports"
    for module, name in (("read_annotate", "diamond_cazy_per_file"), ("read_annotate", "kraken2_summary"), ("mag_annotate", "quast"),
                         ("eukaryote", "tools"), ("contig_annotate", "genes_per_assembly")):
        check(f"{module}: {name} is still there", (tables / module / "tables" / f"{name}.tsv").exists(), True)


def real(project, expected_file):
    check_reports_exist(project)
    with open(expected_file) as handle:
        for line in csv.DictReader((l for l in handle if not l.startswith("#")), delimiter="\t"):
            rows = table(project, line["module"], line["table"])
            if line["assembly"]:
                rows = [r for r in rows if r["assembly_id"] == line["assembly"]]
            found = row(rows, line["key_column"], line["key"])[line["column"]]
            wanted = line["value"]
            try:
                check(line["label"], float(found), float(wanted))
            except ValueError:
                check(line["label"], found, wanted)


if __name__ == "__main__":
    if sys.argv[1] == "synthetic":
        synthetic(sys.argv[2])
    elif sys.argv[1] == "empty":
        check_reports_exist(sys.argv[2])
    elif sys.argv[1] == "broken":
        broken(sys.argv[2])
    else:
        real(sys.argv[2], sys.argv[3])
    if failures:
        print(f"\n{len(failures)} checks failed:")
        for label in failures:
            print(" -", label)
        sys.exit(1)
    print("\nAll checks passed.")
