#!/usr/bin/env bash
# Prepare the project for a real run of the pipeline's rules on a computer that has only Docker.
# Usage: prepare.sh <folder with the *_subset.fastq.gz files> <new project folder> [read pairs per sample]
# Set PYTHON to a Python that has the yaml module, if the first python3 in the PATH doesn't.
set -euo pipefail
subsets=$1 project=$2 pairs=${3:-1000000}
pipeline="$(cd "$(dirname "$0")/../../.." && pwd)"
mkdir -p "$project/reads" "$project/resources/reference" "$project/tmp"
cd "$project"
[ -e config ] || cp -r "$pipeline/config" .
for sample in ERR2019410 ERR2019412 ERR2019415; do
    for end in 1 2; do
        out="reads/${sample}_$end.fastq.gz"
        if [ ! -s "$out" ]; then
            gzip -dc "$subsets/${sample}_${end}_subset.fastq.gz" | head -n $((pairs * 4)) | gzip -6 > "$out" || true
        fi
    done
done
adapter1=AGATCGGAAGAGCACACGTCTGAACTCCAGTCA
adapter2=AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT
{
    printf 'sample_id\tlibrary_id\tforward_filename\treverse_filename\tforward_adapter\treverse_adapter\tassembly_ids\n'
    printf 'ERR2019410\tlib1\treads/ERR2019410_1.fastq.gz\treads/ERR2019410_2.fastq.gz\t%s\t%s\tERR2019410, coasm\n' $adapter1 $adapter2
    printf 'ERR2019412\tlib1\treads/ERR2019412_1.fastq.gz\treads/ERR2019412_2.fastq.gz\t%s\t%s\tcoasm\n' $adapter1 $adapter2
    printf 'ERR2019415\tlib1\treads/ERR2019415_1.fastq.gz\treads/ERR2019415_2.fastq.gz\t%s\t%s\tcoasm\n' $adapter1 $adapter2
} > config/samples.tsv
# The genome of the phage PhiX, a usual spike-in of Illumina runs, stands in for a host genome
[ -s resources/reference/phix.fa.gz ] || curl -sS --fail "https://www.ebi.ac.uk/ena/browser/api/fasta/J02482.1" | gzip > resources/reference/phix.fa.gz
# The marker genes of MAGScoT and the three databases small enough for this computer
base=https://a3s.fi/Holoruminant-data
[ -d resources/MAGScoT ] || curl -sS --fail "$base/2025.04.04.MAGScoT.tar.gz" | tar -xzf - -C resources
mkdir -p resources/databases
[ -d resources/databases/hyddb ] || curl -sS --fail "$base/2025.11.26.hyddb.tar.gz" | tar -xzf - -C resources/databases
[ -d resources/databases/camper ] || curl -sS --fail "$base/2025.04.04.camper.tar.gz" | tar -xzf - -C resources/databases
[ -d resources/databases/ncyc ] || curl -sS --fail "$base/2026.02.18.ncyc.tar.gz" | tar -xzf - -C resources/databases
"${PYTHON:-python3}" - "$pipeline" <<'PY'
import sys, yaml
pipeline = sys.argv[1]
c = yaml.safe_load(open("config/config.yaml"))
c["pipeline_folder"] = pipeline + "/"
c["tmp_storage"] = "/tmp"
c["nvme_storage"] = "/tmp"
c["assembler"] = "megahit"
tier = {"runtime": 600, "mem_mb": 6500, "cpus": 8, "partition": "local", "nvme": "nvme:0"}
c["resource_sets"] = {name: dict(tier) for name in c["resource_sets"]}
yaml.safe_dump(c, open("config/config.yaml", "w"), sort_keys=False)
f = yaml.safe_load(open("config/features.yaml"))
f["hosts"] = {"phix": "resources/reference/phix.fa.gz"}
yaml.safe_dump(f, open("config/features.yaml", "w"), sort_keys=False)
d = yaml.safe_load(open("config/.docker.yml"))
# Steps that only need ln, bgzip, fastqc and samtools share images that are here anyway, to save 7 GB
d["reads"] = "docker://fischuu/hrp_bowtie2:0.1"
d["reference"] = "docker://fischuu/hrp_bowtie2:0.1"
d["helpers"] = "docker://fischuu/hrp_preprocess:0.8"
yaml.safe_dump(d, open("config/.docker.yml", "w"), sort_keys=False)
PY
du -sh reads
# This small project gives one bin with the default settings, and dRep can't work with a single genome. CheckM,
# inside dRep, needs far more memory than this computer has. Neither is an issue with a real amount of data on a
# cluster. So that the steps after dRep can run here too, keep more bins, and skip the quality filter of dRep.
"${PYTHON:-python3}" - <<'PY'
import yaml
p = yaml.safe_load(open("config/params.yaml"))
p["assemble"]["magscot"]["threshold"] = "0.2"
p["assemble"]["drep"]["extra"] = "--ignoreGenomeQuality"
yaml.safe_dump(p, open("config/params.yaml", "w"), sort_keys=False)
PY
