#!/usr/bin/env bash
# Runs in the container: the real DIAMOND rules with a stand-in for diamond, in each storage situation.
set -uo pipefail
export PATH=/pipeline/tests/diamond_staging/stubs:/opt/snakemake/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

project=/tmp/diamond_test
source_db=resources/db/test.dmnd
export DIAMOND_CALLS=/tmp/diamond_calls.txt
failures=0

check() {  # <description> <expected> <actual>
    if [ "$2" = "$3" ]; then
        echo "ok: $1"
    else
        echo "FAILED: $1: expected [$2], got [$3]"
        failures=$((failures + 1))
    fi
}

prepare_project() {  # <copy_dbs> <diamond_shm> <shm_storage> <nvme_storage> <resource sets>
    rm -rf "$project" "$DIAMOND_CALLS" /tmp/nvme
    mkdir -p "$project" /tmp/nvme
    cd "$project" || exit 1
    cp -r /pipeline/config/. config/
    mkdir -p resources/db results/preprocess/bowtie2/decontaminated_reads results/contig_annotate/prodigal/a1
    echo "a database" > "$source_db"
    touch results/preprocess/bowtie2/decontaminated_reads/s1.L1_1.fq.gz
    touch results/preprocess/bowtie2/decontaminated_reads/s1.L1_2.fq.gz
    touch results/contig_annotate/prodigal/a1/a1.prodigal.fa
    printf 'sample_id\tlibrary_id\tforward_filename\treverse_filename\tforward_adapter\treverse_adapter\tassembly_ids\ns1\tL1\tr1.gz\tr2.gz\tA\tC\ta1\n' > config/samples.tsv
    python - "$@" <<'PY'
import sys
import yaml
copy_dbs, diamond_shm, shm, nvme, _ = sys.argv[1:]
c = yaml.safe_load(open("config/config.yaml"))
c.update(pipeline_folder="/pipeline/", copy_dbs=copy_dbs, diamond_shm=diamond_shm, shm_storage=shm, nvme_storage=nvme)
yaml.safe_dump(c, open("config/config.yaml", "w"))
f = yaml.safe_load(open("config/features.yaml"))
f["databases"]["diamond"] = {"test": "resources/db/test.dmnd"}
f["databases"]["diamond_contig_protein"] = {"test": "resources/db/test.dmnd"}
yaml.safe_dump(f, open("config/features.yaml", "w"))
PY
    printf 'read_annotate__diamond__assign: %s\ncontig_annotate__diamond__assign: %s\n' "$5" "$5" > config/escalation.yaml
}

run_rule() {  # <rule> <target>
    snakemake -s /pipeline/workflow/Snakefile --configfile config/config.yaml --cores 1 \
        --allowed-rules "$1" --latency-wait 1 "$2" > run.log 2>&1
}

database_used() {
    if [ -f "$DIAMOND_CALLS" ]; then sort -u "$DIAMOND_CALLS" | tr '\n' ';'; fi
}

for rule in read_annotate__diamond__assign contig_annotate__diamond__assign; do
    if [ "$rule" = read_annotate__diamond__assign ]; then
        target=results/read_annotate/diamond/test/s1.L1_R1.out
    else
        target=results/contig_annotate/diamond/test/a1.out
    fi

    echo "== $rule: no fast storage and one resource set: run from the original place"
    prepare_project True True /nonexistent /nonexistent medium
    run_rule "$rule" "$target"
    check "the rule finishes" 0 $?
    check "diamond reads the original database" "$source_db;" "$(database_used)"

    echo "== $rule: no fast storage and two resource sets: only the last attempt runs in place"
    prepare_project True True /nonexistent /nonexistent "medium, large"
    run_rule "$rule" "$target"
    check "the rule finishes" 0 $?
    check "the first attempt gives up, so there is one retry" 1 "$(grep -c 'Trying to restart' run.log)"
    check "diamond reads the original database" "$source_db;" "$(database_used)"

    echo "== $rule: copy_dbs off and /dev/shm allowed: nothing is copied, and that is no error"
    prepare_project False True /dev/shm /nonexistent medium
    run_rule "$rule" "$target"
    check "the rule finishes" 0 $?
    check "diamond reads the original database" "$source_db;" "$(database_used)"

    echo "== $rule: the database fits into /dev/shm: use the copy and remove it"
    prepare_project True True /dev/shm /nonexistent medium
    run_rule "$rule" "$target"
    check "the rule finishes" 0 $?
    check "diamond reads the copy" "/dev/shm/test/test;" "$(database_used)"
    check "the copy is gone" 0 "$(ls /dev/shm/test 2>/dev/null | wc -l)"

    echo "== $rule: /dev/shm not allowed, the local disk has room: use the copy there"
    prepare_project True False /dev/shm /tmp/nvme medium
    run_rule "$rule" "$target"
    check "the rule finishes" 0 $?
    check "diamond reads the copy" "/tmp/nvme/test/test;" "$(database_used)"
done

if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "All checks passed"
