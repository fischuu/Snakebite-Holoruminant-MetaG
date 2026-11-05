#!/usr/bin/env bash
# Write the tool versions of every container to book_run/versions/. Call it in the project folder,
# after a run, when the images are in docker_images/. An image that isn't there is pulled.
set -uo pipefail

runner="$(command -v apptainer || command -v singularity || true)"
if [ -z "$runner" ]; then
    echo "ERROR: neither apptainer nor singularity found" >&2
    exit 1
fi
export APPTAINER_TMPDIR="$PWD/tmp/apptainer" APPTAINER_CACHEDIR="$PWD/tmp/apptainer"
mkdir -p book_run/versions "$APPTAINER_TMPDIR"

# Runs inside each container: it reports the tools that this container has
report='
report() {
    command -v "$1" > /dev/null 2>&1 || return 0
    printf "%s\t%s\t" "$1" "$(command -v "$1")"
    "$@" 2>&1 | grep -v "^$" | head -n 2 | tr "\n" " "
    echo
}
report fastqc --version; report fastp --version; report bowtie2 --version; report samtools --version
report kraken2 --version; report ktImportTaxonomy; report singlem --version; report sylph --version
report nonpareil -V; report metaphlan --version; report humann --version; report phyloFlash.pl -version
report diamond version; report megahit --version; report metaspades.py --version; report concoct --version
report run_MaxBin.pl -v; report metabat2 --help; report prodigal -v; report hmmsearch -h; report MAGScoT.R --help
report dRep --version; report quast --version; report checkm2 --version; report gtdbtk --version
report DRAM.py --version; report bakta --version; report camper_annotate --version; report emapper.py --version
report phylophlan --version; report proteinortho --version; report coverm --version; report featureCounts -v
report tiara --version; report remag --version; report bgzip --version; report pigz --version; report seqtk
report parallel --version; report Rscript --version; report python --version
if command -v conda > /dev/null 2>&1; then echo "--- conda list"; conda list 2>/dev/null; fi
'

grep -E '^[A-Za-z0-9_]+:[[:space:]]*"docker://' config/.docker.yml | while IFS= read -r line; do
    key="${line%%:*}"
    url="$(echo "$line" | sed -E 's/^[^"]*"([^"]*)".*/\1/')"
    # Snakemake names an image after the checksum of its address
    image="docker_images/$(printf '%s' "$url" | md5sum | cut -d' ' -f1).simg"
    [ -f "$image" ] || image="$url"
    echo "$key: $url"
    {
        echo "image: $url"
        "$runner" exec "$image" bash -c "$report"
    } > "book_run/versions/$key.txt" 2>&1 < /dev/null
done
echo "Written to book_run/versions/"
