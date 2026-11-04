#!/usr/bin/env bash
# Read the tool versions out of the images in config/.docker.yml into book/examples/container_versions.tsv.
# Needs Docker. Usage: container_versions.sh [--remove] [key ...]
# With --remove, an image that wasn't here before is removed again, for computers with little disk space.
# The versions are the conda package names, so nothing has to run in the images but "find" and "ls".
set -uo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
table="$repo/book/examples/container_versions.tsv"
tools='fastqc|fastp|bowtie2|samtools|htslib|kraken2|krona|singlem|sylph|nonpareil|metaphlan|humann|phyloflash|diamond|megahit|spades|concoct|maxbin2|metabat2|prodigal|pyrodigal|hmmer|drep|quast|checkm2|checkm-genome|gtdbtk|dram|bakta|camper_dram|camper|eggnog-mapper|phylophlan|proteinortho|coverm|subread|tiara|remag|seqtk|pigz|parallel|r-base|python|fastani|skani|mash|pplacer|mmseqs2|trnascan-se|barrnap|bbmap|vsearch|blast|csvkit|rsync'

remove=0
if [ "${1:-}" = "--remove" ]; then
    remove=1
    shift
fi

keys=("$@")
if [ ${#keys[@]} -eq 0 ]; then
    while IFS= read -r key; do keys+=("$key"); done < <(sed -nE 's/^([A-Za-z0-9_]+):[[:space:]]*"docker:.*/\1/p' "$repo/config/.docker.yml")
fi

[ -f "$table" ] || printf 'key\timage\ttool\tversion\n' > "$table"

for key in "${keys[@]}"; do
    image="$(sed -nE "s/^$key:[[:space:]]*\"docker:\/\/([^\"]+)\".*/\1/p" "$repo/config/.docker.yml")"
    if [ -z "$image" ]; then
        echo "$key: not in config/.docker.yml" >&2
        continue
    fi
    grep -q "^$key	" "$table" && continue
    was_here=1
    if ! docker image inspect "$image" > /dev/null 2>&1; then
        was_here=0
        if ! docker pull -q --platform linux/amd64 "$image" > /dev/null 2>&1; then
            echo "$key: can't pull $image" >&2
            continue
        fi
    fi
    packages="$(docker run --rm --platform linux/amd64 --entrypoint sh "$image" -c \
        'for d in $(find / -maxdepth 6 -type d -name conda-meta 2>/dev/null); do ls "$d" | grep "\.json$"; done
         # DRAM and CAMPER are installed with pip, inside a conda environment
         find / -maxdepth 9 -type d \( -name "DRAM_bio-*.dist-info" -o -name "camper_dramkit-*.dist-info" \) 2>/dev/null \
             | sed -E "s|.*/DRAM_bio-([^/]*)\.dist-info|dram-\1-pip.json|; s|.*/camper_dramkit-([^/]*)\.dist-info|camper_dram-\1-pip.json|"' 2>/dev/null)"
    found=0
    while IFS= read -r package; do
        # name-version-build.json
        name="$(echo "$package" | sed -E 's/-[^-]+-[^-]+\.json$//')"
        version="$(echo "$package" | sed -E 's/^.*-([^-]+)-[^-]+\.json$/\1/')"
        if echo "$name" | grep -qE "^($tools)$"; then
            printf '%s\t%s\t%s\t%s\n' "$key" "$image" "$name" "$version" >> "$table"
            found=1
        fi
    done <<< "$packages"
    [ "$found" -eq 1 ] || printf '%s\t%s\t(no conda packages)\t\n' "$key" "$image" >> "$table"
    echo "$key: done"
    if [ "$remove" -eq 1 ] && [ "$was_here" -eq 0 ]; then
        docker rmi -f "$image" > /dev/null 2>&1
    fi
done
