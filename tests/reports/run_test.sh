#!/usr/bin/env bash
# Test the module reports: they are rendered as on a compute node (no network, a read-only image, not
# root) for a project with output of all tools, and for a project that hasn't run. The tables are then
# compared with the known numbers.
#
# Usage: run_test.sh [real project]
#   With a project of real results, as from book/examples/real_tools/, its reports are checked as well.
#   LOCAL_R=1 uses the local R and LaTeX instead of the container, which is faster, for development.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
pipeline="$(cd "$here/../.." && pwd)"
image=$(sed -n 's/^report: "docker:\/\/\([^"]*\)".*/\1/p' "$pipeline/config/.docker.yml")
modules="reads reference preprocess read_annotate assemble quantify mag_annotate contig_annotate eukaryote"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The rule tables that the Snakefile would pass. For the helper rules and for the resource cases of
# make_project.py the benchmarks are in the same place as in a real run.
rule_table() {
    case "$1" in
        reads) echo "helpers__fastqc|{prefix}_fastqc_benchmark.tsv|0" ;;
        reference) echo "reference__hosts__recompress|results/reference/hosts/benchmark/{genome}.tsv|0" ;;
        preprocess) echo "preprocess__fastp__run|results/preprocess/fastp/benchmark/{sample_id}.{library_id}.tsv|0" ;;
        read_annotate) echo "read_annotate__nonpareil__run|results/read_annotate/nonpareil/benchmark/{sample_id}.{library_id}.tsv|0" ;;
        assemble)
            table=""
            for rule in retried oversized near_memory near_time not_measured fits on_nvme no_log; do
                table="$table;assemble__$rule|results/assemble/cases/$rule/benchmark/{x}.tsv|0"
            done
            echo "${table#;};assemble__on_shm|results/assemble/cases/on_shm/benchmark/{x}.tsv|1" ;;
        *) echo "" ;;
    esac
}

render() {  # <project> <rule table given by Snakemake, or empty for the test's own>
    local project=$1 tables=${2:-} module table
    mkdir -p "$project/Rreports"
    for module in $modules; do
        table=$(rule_table "$module")
        if [ -n "$tables" ]; then
            table=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])" "$tables" "$module")
        fi
        if [ "${LOCAL_R:-0}" = 1 ]; then
            Rscript "$pipeline/workflow/scripts/R/render_report.R" "module=$module" "project=$project" "pipeline=$pipeline" \
                features=config/features.yaml samples=config/samples.tsv "output=Rreports/$module.pdf" version=test \
                snakemake=test "rules=$table" > "$work/$module.log" 2>&1 || { tail -n 20 "$work/$module.log"; exit 1; }
        else
            docker run --rm --platform linux/amd64 --network none --read-only --tmpfs /tmp --user "$(id -u):$(id -g)" \
                -e HOME=/tmp/home -v "$project":"$project" -v "$pipeline":"$pipeline":ro -w "$project" "$image" \
                Rscript "$pipeline/workflow/scripts/R/render_report.R" "module=$module" "project=$project" "pipeline=$pipeline" \
                features=config/features.yaml samples=config/samples.tsv "output=Rreports/$module.pdf" version=test \
                snakemake=test "rules=$table" > "$work/$module.log" 2>&1 || { tail -n 20 "$work/$module.log"; exit 1; }
        fi
        echo "rendered $module"
    done
}

# The versions of the tables of tools come from the book's list, where there is a book
if [ -f "$pipeline/book/examples/container_versions.tsv" ]; then
    diff -q "$pipeline/book/examples/container_versions.tsv" "$pipeline/workflow/scripts/R/tool_versions.tsv"
fi

echo "== A project with output of all tools =="
python3 "$here/make_project.py" "$work/full" "$pipeline"
# Docker on a Mac wants the real path
full=$(cd "$work/full" && pwd -P)
render "$full"
python3 "$here/check_project.py" synthetic "$full"

echo
echo "== A project that hasn't run =="
python3 "$here/make_project.py" "$work/empty" "$pipeline" --empty
empty=$(cd "$work/empty" && pwd -P)
render "$empty"
python3 "$here/check_project.py" empty "$empty"

if [ $# -ge 1 ]; then
    echo
    echo "== Real results: $1 =="
    if [ -n "${RULE_TABLES:-}" ]; then
        render "$1" "$RULE_TABLES"
    else
        render "$1"
    fi
    python3 "$here/check_project.py" real "$1" "$here/expected_real.tsv"
fi
echo
echo "All report tests passed."
