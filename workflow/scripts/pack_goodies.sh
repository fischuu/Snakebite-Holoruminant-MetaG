#!/usr/bin/env bash
# Bundle the final deliverables of a completed pipeline run into a single
# archive. Run manually from the project folder after mag_annotate/quantify
# have finished; this is not called by any Snakemake rule.

set -euo pipefail

archive="${1:-final_results.tar.gz}"

deliverables=(
    reports
    results/assemble/drep/dereplicated_genomes.fa.gz
    results/quantify/coverm/*.tsv
    results/mag_annotate/checkm2/quality_report.tsv
    results/mag_annotate/gtdbtk/gtdbtk.summary.tsv
    results/mag_annotate/dram/annotate/annotations.tsv
    results/mag_annotate/dram/product.tsv
    results/mag_annotate/dram/product.html
    results/mag_annotate/dram/metabolism_summary.xlsx
)

present=()
for path in "${deliverables[@]}"; do
    # shellcheck disable=SC2086 # intentional globbing for the coverm tsvs
    for match in $path; do
        [ -e "$match" ] && present+=("$match")
    done
done

if [ "${#present[@]}" -eq 0 ]; then
    echo "Nothing found to pack -- has the pipeline finished running?" >&2
    exit 1
fi

tar --create --verbose --file "$archive" --use-compress-program="pigz" "${present[@]}"
