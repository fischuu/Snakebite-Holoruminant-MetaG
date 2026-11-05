#!/usr/bin/env bash
# Test that the options of the Krona rule draw a Kraken2 report correctly, with the real tool in its container and
# the pipeline's taxonomy. Needs Docker and a download of 30 MB, plus the container if it isn't there yet.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
image=$(sed -nE 's/^krona:[[:space:]]*"docker:\/\/([^"]+)".*/\1/p' "$repo/config/.docker.yml")
command=$(grep -oE 'ktImportTaxonomy .*\{input\}' "$repo/workflow/rules/read_annotate/krona.smk" | sed -E 's/ \{input\}$//')
taxonomy_url="${KRONA_TAXONOMY_URL:-https://a3s.fi/Holoruminant-data/2025.04.04.krona.tar.gz}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -sS --fail "$taxonomy_url" | tar -xzf - -C "$work"

# A report in Kraken2's format: percentage, reads in the clade, reads of this taxon, rank, taxon, name.
# The counts on purpose don't look like taxa of these organisms.
printf ' 10.00\t100\t100\tU\t0\tunclassified\n' > "$work/test.report"
printf ' 90.00\t900\t0\tR\t1\troot\n' >> "$work/test.report"
printf ' 90.00\t900\t0\tR1\t131567\t  cellular organisms\n' >> "$work/test.report"
printf ' 90.00\t900\t50\tD\t2\t    Bacteria\n' >> "$work/test.report"
printf ' 80.00\t800\t800\tS\t562\t      Escherichia coli\n' >> "$work/test.report"
printf '  5.00\t50\t50\tS\t1280\t      Staphylococcus aureus\n' >> "$work/test.report"

echo "Running: $command"
docker run --rm --platform linux/amd64 --entrypoint bash -v "$work":/work -w /work "$image" \
    -c "$command test.report -o chart.html --tax /work/krona" > /dev/null

failures=0
magnitude() {  # <organism>: the number of reads the chart shows for it, empty if it isn't there
    # Krona writes the fields of a node in a random order, so look through the whole node
    awk -v node="<node name=\"$1\">" '
        index($0, node) { inside = 1; next }
        inside && /<node |<\/node>/ { exit }
        inside && match($0, /<magnitude><val>[0-9]+/) {
            value = substr($0, RSTART, RLENGTH)
            gsub(/[^0-9]/, "", value)
            print value
            exit
        }
    ' "$work/chart.html"
}
check() {  # <description> <expected> <actual>
    if [ "$2" = "$3" ]; then
        echo "ok: $1"
    else
        echo "FAILED: $1: expected [$2], got [$3]"
        failures=$((failures + 1))
    fi
}
check "Escherichia coli has its 800 reads" 800 "$(magnitude "Escherichia coli")"
check "Staphylococcus aureus has its 50 reads" 50 "$(magnitude "Staphylococcus aureus")"
check "the unclassified reads are in the chart" 100 "$(magnitude "No hits")"
check "read counts aren't taken for taxa" 0 "$(grep -c 'Ancylobacter' "$work/chart.html")"

if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "All checks passed"
