#!/usr/bin/env bash
# Transpose a wide TSV of "percent unmapped" values into a long/tidy table,
# converting each value to "percent mapped" (100 - value) along the way.
# The header of each column is expected to be underscore-separated as
# <sample>_<library>_<reference>; that gets split into three output columns.
#
# Usage: transpose_table.sh [input.tsv] [output.tsv]

set -euo pipefail

input="${1:-unmapped.tsv}"
output="${2:-longer.tsv}"

n_cols=$(head -n1 "$input" | awk -F'\t' '{print NF}')

: > "$output"
for col in $(seq 1 "$n_cols"); do
    cut -f"$col" "$input" | awk -F'_' '
        NR == 1 {
            printf "%s\t%s\t%s\n", $1, $2, $3
            next
        }
        {
            printf "%.5f\n", 100 - $1
        }
    ' | paste -sd'\t' - >> "$output"
done
