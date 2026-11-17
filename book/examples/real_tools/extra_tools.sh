#!/usr/bin/env bash
# Run more tools with the pipeline's own rules, on the project of prepare.sh. These tools have a database small enough
# for a laptop, or a small real alternative to the one of a real run, or none at all. Part IV quotes the results.
# Usage: extra_tools.sh <project> <step>
#   Steps: kraken2 diamond sylph checkm2 bakta proteinortho phyloflash remag, and
#          spades <new project>, which makes a copy of the project with metaSPAdes as the assembler, as 4CAC needs its graph
# Set SNAKEMAKE and PYTHON as for run.sh. A step leaves its database in place, so delete it afterwards if disk space is short.
set -euo pipefail

project=$1
step=$2
tools="$(cd "$(dirname "$0")" && pwd)"
export SNAKEMAKE="${SNAKEMAKE:-snakemake}"
PYTHON="${PYTHON:-python3}"
base=https://a3s.fi/Holoruminant-data

cd "$project"

set_yaml() {  # <file> <python statements on the dictionary d>
    "$PYTHON" - "$1" "$2" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
exec(sys.argv[2])
yaml.safe_dump(d, open(sys.argv[1], "w"), sort_keys=False)
PY
}

run() {
    bash "$tools/run.sh" "$project" "$@" --rerun-triggers mtime
}

case "$step" in
    kraken2)
        # The Standard-8 database of Ben Langmead's collection: the real tool and real genomes, capped at 8 GB.
        # A real run uses the complete Standard database of the same date, which needs about 140 GB of memory.
        db=resources/databases/kraken2/k2_standard_08gb_20240112
        if [ ! -s "$db/hash.k2d" ]; then
            mkdir -p "$db"
            curl -sS --fail https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08gb_20240112.tar.gz | tar -xzf - -C "$db"
        fi
        [ -d resources/databases/krona ] || curl -sS --fail "$base/2025.04.04.krona.tar.gz" | tar -xzf - -C resources/databases
        set_yaml config/features.yaml "d['databases']['kraken2'] = {'standard_08gb': '$db'}; d['databases']['krona'] = 'resources/databases/krona'"
        # Don't stage the database: a copy would fill the disk of the container
        set_yaml config/config.yaml "d['copy_dbs'] = 'False'"
        run read_annotate__kraken2 read_annotate__krona
        ;;
    spades)
        new=$3
        mkdir -p "$new/results"
        cp -c -R -p config reads "$new/"
        cp -c -R -p results/preprocess results/reads results/reference "$new/results/"
        cd "$new"
        new="$(pwd)"
        set_yaml config/config.yaml "d['assembler'] = 'metaspades'"
        bash "$tools/run.sh" "$new" results/assemble/metaspades/coasm.fa.gz results/assemble/metaspades/ERR2019410.fa.gz \
            eukaryote__tiara eukaryote__4cac --rerun-triggers mtime --keep-going
        ;;
    diamond)
        if [ ! -d resources/databases/diamond ]; then
            curl -sS --fail "$base/2025.11.25.diamond.tar.gz" | tar -xzf - -C resources/databases
        fi
        set_yaml config/.docker.yml "d['mag_annotate'] = 'docker://fischuu/hrp_preprocess:0.8'"
        run read_annotate__diamond contig_annotate__diamond
        ;;
    sylph)
        # A real sylph database needs more memory than this computer has. So this one holds only the genome of this run,
        # to show the tool's real output. Reads from other organisms stay unassigned.
        db=resources/databases/sylph/own_catalogue.syldb
        mkdir -p resources/databases/sylph
        if [ ! -s "$db" ]; then
            docker run --rm --platform linux/amd64 --entrypoint bash -v "$PWD":/w -w /w fischuu/sylph:0.8.1_0.1 -c \
                "sylph sketch -o resources/databases/sylph/own_catalogue -g results/assemble/drep/dereplicated_genomes/*"
        fi
        set_yaml config/features.yaml "d['databases']['sylph'] = '$db'"
        run read_annotate__sylph
        ;;
    checkm2)
        if [ ! -d resources/databases/checkm2 ]; then
            curl -sS --fail "$base/2025.04.04.checkm2.tar.gz" | tar -xzf - -C resources/databases
        fi
        run mag_annotate__checkm2
        ;;
    bakta)
        # The light database of Bakta instead of the full one, which is 73 GB as a download
        db=resources/databases/bakta/db
        if [ ! -d "$db" ]; then
            mkdir -p resources/databases/bakta
            curl -sSL --fail https://zenodo.org/records/10522951/files/db-light.tar.gz | tar -xzf - -C resources/databases/bakta
            mv resources/databases/bakta/db-light "$db"
            # The AMRFinderPlus database of this archive doesn't fit the AMRFinderPlus of the image. Without this, Bakta
            # stops at that step after all the others, with this command as its advice.
            docker run --rm --platform linux/amd64 --entrypoint bash -v "$PWD":/w -w /w fischuu/hrp_annotate:0.4 -c \
                "amrfinder_update --force_update --database $db/amrfinderplus-db"
        fi
        set_yaml config/features.yaml "d['databases']['bakta'] = '$db'"
        set_yaml config/.docker.yml "d['mag_annotate'] = 'docker://fischuu/hrp_annotate:0.4'"
        run mag_annotate__bakta
        ;;
    proteinortho)
        set_yaml config/.docker.yml "d['mag_annotate'] = 'docker://fischuu/hrp_annotate:0.4'"
        run mag_annotate__proteinortho
        ;;
    phyloflash)
        if [ ! -d resources/databases/phyloflash ]; then
            curl -sS --fail "$base/2025.11.25.phyloflash.tar.gz" | tar -xzf - -C resources/databases
        fi
        run read_annotate__phyloflash
        ;;
    remag)
        # Under emulation Intel's OpenMP can't read the layout of the processor, and it aborts when it tries to pin its
        # threads. A real computer doesn't need this.
        export KMP_AFFINITY=disabled
        # With the default of 1024, it was killed three times after 16 minutes with the 7 GB of this computer
        set_yaml config/params.yaml "d['eukaryote']['remag']['hyenadna_batch_size'] = 16"
        run eukaryote__remag --keep-going
        ;;
    *)
        echo "unknown step: $step" >&2
        exit 1
        ;;
esac
