#!/usr/bin/env bash
# Prepare a project folder for a complete run of the pipeline on the example data. See README.md.
set -euo pipefail

usage() {
    cat >&2 <<'USAGE'
Usage: setup_project.sh --project <new folder> --account <SLURM account> --resources <folder> [options]

  --project    Folder to create for this run, on your scratch space
  --account    SLURM account the jobs are billed to, e.g. project_2009831
  --resources  Existing folder with databases/, reference/ and MAGScoT/
  --reads      Existing folder with the example reads. Without it they are downloaded (28 GB)
  --full       Use the full read files (61-77 million pairs per sample), not the 10-million-pair subsets
USAGE
    exit 2
}

project="" account="" resources="" reads="" suffix="_subset"
while [ $# -gt 0 ]; do
    case "$1" in
        --project) project=${2:?}; shift 2 ;;
        --account) account=${2:?}; shift 2 ;;
        --resources) resources=${2:?}; shift 2 ;;
        --reads) reads=${2:?}; shift 2 ;;
        --full) suffix=""; shift ;;
        *) usage ;;
    esac
done
[ -n "$project" ] && [ -n "$account" ] && [ -n "$resources" ] || usage

pipeline="$(cd "$(dirname "$0")/../.." && pwd)"
samples="ERR2019410 ERR2019412 ERR2019415"
reads_url="${READS_URL:-https://a3s.fi/Holoruminant-data/2025.11.25.reads.tar.gz}"

[ -d "$resources" ] || { echo "ERROR: no such resources folder: $resources" >&2; exit 1; }
if [ -e "$project/config" ]; then
    echo "ERROR: $project is already set up. Choose a new folder, or remove this one first." >&2
    exit 1
fi

mkdir -p "$project"
project="$(cd "$project" && pwd)"
cd "$project"
mkdir -p tmp/apptainer book_run

# The configuration of this run stays in the project folder, as for any other project
cp -r "$pipeline/config" .
sed -i "s|^pipeline_folder:.*|pipeline_folder: \"$pipeline/\"|" config/config.yaml

mkdir -p config/profiles/book_run
sed "s|slurm_account:.*|slurm_account: \"$account\"|" config/profiles/Puhti/config.yaml \
    > config/profiles/book_run/config.yaml

cp "$pipeline/run_Snakebite-Holoruminant-MetaG.sh" .
sed -i \
    -e "s|^projectFolder=.*|projectFolder=\"$project\"|" \
    -e 's|^Profile=.*|Profile=$projectFolder/config/profiles/book_run|' \
    -e 's|^export APPTAINER_TMPDIR=.*|export APPTAINER_TMPDIR="$projectFolder/tmp/apptainer"|' \
    -e 's|^export APPTAINER_CACHEDIR=.*|export APPTAINER_CACHEDIR="$projectFolder/tmp/apptainer"|' \
    run_Snakebite-Holoruminant-MetaG.sh

ln -s "$(cd "$resources" && pwd)" resources

if [ -n "$reads" ]; then
    ln -s "$(cd "$reads" && pwd)" reads
else
    members=""
    for sample in $samples; do
        members="$members reads/${sample}_1$suffix.fastq.gz reads/${sample}_2$suffix.fastq.gz"
    done
    echo "Downloading the example reads, 28 GB. Only the files of this run are kept on disk."
    # shellcheck disable=SC2086
    curl -sS --fail -L "$reads_url" | tar -xzf - $members
fi

# Every sample gets its own assembly, and all of them go into one co-assembly
adapter1=AGATCGGAAGAGCACACGTCTGAACTCCAGTCA
adapter2=AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT
{
    printf 'sample_id\tlibrary_id\tforward_filename\treverse_filename\tforward_adapter\treverse_adapter\tassembly_ids\n'
    for sample in $samples; do
        printf '%s\tlib1\treads/%s_1%s.fastq.gz\treads/%s_2%s.fastq.gz\t%s\t%s\t%s, coasm\n' \
            "$sample" "$sample" "$suffix" "$sample" "$suffix" "$adapter1" "$adapter2" "$sample"
    done
} > config/samples.tsv

# What would stop the run later on is better found now
problems=0
for sample in $samples; do
    for end in 1 2; do
        file="reads/${sample}_$end$suffix.fastq.gz"
        if [ ! -s "$file" ]; then
            echo "MISSING read file: $file"
            problems=$((problems + 1))
        fi
    done
done
for path in $(grep -vE '^[[:space:]]*#' config/features.yaml | grep -oE 'resources/[^ #]+'); do
    # A database can be a file, a folder, or the prefix of several files
    if ! ls -d "$path"* > /dev/null 2>&1; then
        echo "MISSING in features.yaml: $path"
        problems=$((problems + 1))
    fi
done
for folder in /scratch /projappl /users /run; do
    if [ ! -e "$folder" ]; then
        echo "CHECK run_Snakebite-Holoruminant-MetaG.sh: it binds $folder into the containers, and it doesn't exist here"
        problems=$((problems + 1))
    fi
done
for folder in "$project" "$pipeline" "$(cd "$resources" && pwd)" "$(cd reads && pwd)"; do
    case "$folder" in
        /scratch/* | /projappl/* | /users/*) ;;
        *)
            echo "CHECK run_Snakebite-Holoruminant-MetaG.sh: containers can't see $folder unless you bind it"
            problems=$((problems + 1))
            ;;
    esac
done

cat <<NEXT

Project folder: $project
Pipeline:       $pipeline ($(git -C "$pipeline" rev-parse --short HEAD 2>/dev/null || echo "no git"))
Problems found: $problems

Before you start, compare these with your cluster:
  - the partitions and sizes under resource_sets in config/config.yaml
  - the lines 'module load' and '--singularity-args' in run_Snakebite-Holoruminant-MetaG.sh

Then go on with:
  cd $project
  bash $pipeline/tests/real_run/run_stage.sh reads
NEXT
