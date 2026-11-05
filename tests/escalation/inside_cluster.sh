#!/usr/bin/env bash
# Runs in the mini cluster: the real Snakefile and rules on real SLURM, with a stand-in for bgzip.
set -uo pipefail
export PATH=/opt/snakemake/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

project=/scratch/project_demo/escalation_test
target=results/reference/hosts/testhost.fa.gz
failures=0

check() {  # <description> <expected> <actual>
    if [ "$2" = "$3" ]; then
        echo "ok: $1"
    else
        echo "FAILED: $1: expected [$2], got [$3]"
        failures=$((failures + 1))
    fi
}

prepare_project() {  # <the escalation of the rule>
    rm -rf "$project"
    mkdir -p "$project/resources" "$project/config/profiles/mini"
    cd "$project" || exit 1
    cp -r /pipeline/config/. config/
    printf '>contig\nACGT\n' | gzip > resources/testhost.fa.gz
    printf 'sample_id\tlibrary_id\tforward_filename\treverse_filename\tforward_adapter\treverse_adapter\tassembly_ids\ns1\tL1\tr1.gz\tr2.gz\tA\tC\ta1\n' > config/samples.tsv
    python - <<PY
import yaml
c = yaml.safe_load(open("config/config.yaml"))
c["pipeline_folder"] = "/pipeline/"
tier = lambda mem, cpus: {"runtime": 5, "mem_mb": mem, "cpus": cpus, "partition": "small", "nvme": ""}
c["resource_sets"] = {"small": tier(200, 1), "medium": tier(500, 2), "large": tier(1000, 2)}
yaml.safe_dump(c, open("config/config.yaml", "w"))
f = yaml.safe_load(open("config/features.yaml"))
f["hosts"] = {"testhost": "resources/testhost.fa.gz"}
yaml.safe_dump(f, open("config/features.yaml", "w"))
PY
    echo "reference__hosts__recompress: $1" > config/escalation.yaml
    cat > config/profiles/mini/config.yaml <<PROFILE
executor: slurm
jobs: 5
latency-wait: 5
default-resources:
    slurm_account: "project_demo"
    slurm_partition: "small"
    runtime: 5
    mem_mb: 200
    cpus_per_task: 1
PROFILE
}

run_pipeline() {
    PATH=/pipeline/tests/escalation/stubs:$PATH snakemake -s /pipeline/workflow/Snakefile \
        --configfile config/config.yaml --profile config/profiles/mini \
        --restart-times 0 --retries 0 --slurm-keep-successful-logs "$target" > run.log 2>&1
}

jobs_since() {  # <job id>: memory and state of every job after this one
    sacct -X -n --format=JobID,ReqMem,State | awk -v after="$1" '$1 + 0 > after + 0 { printf "%s %s;", $2, $3 }'
}

last_job() {
    sacct -X -n --format=JobID | tail -n 1 | tr -d ' '
}

restarts_inside_jobs() {
    cat .snakemake/slurm_logs/rule_reference__hosts__recompress/*/*.log | grep -c 'Trying to restart'
}

echo "== A rule with two resource sets: the failure gets a new, bigger SLURM job"
prepare_project "small, medium"
start=$(last_job)
run_pipeline
check "the pipeline finishes" 0 $?
check "first job fails with 200 MB, second succeeds with 500 MB" "200M FAILED;500M COMPLETED;" "$(jobs_since "$start")"
check "no retry inside a SLURM job" 0 "$(restarts_inside_jobs)"
check "the result is there" 1 "$(ls "$target" 2>/dev/null | wc -l)"
check "Snakemake reports exactly one retry" 1 "$(grep -c 'Trying to restart' run.log)"

echo "== A rule with one resource set: a failure stays a failure, without any retry"
prepare_project "small"
start=$(last_job)
run_pipeline
check "the pipeline reports the failure" 1 $?
check "exactly one job, which fails" "200M FAILED;" "$(jobs_since "$start")"
check "no retry at all" 0 "$(grep -c 'Trying to restart' run.log)"
check "no retry inside a SLURM job" 0 "$(restarts_inside_jobs)"

echo "== Every resource set gets one attempt, and the last one isn't repeated"
prepare_project "small, small"
start=$(last_job)
run_pipeline
check "the pipeline reports the failure" 1 $?
check "two jobs, both fail" "200M FAILED;200M FAILED;" "$(jobs_since "$start")"

echo "== A rule with one big enough resource set: no retry is needed"
prepare_project "medium"
start=$(last_job)
run_pipeline
check "the pipeline finishes" 0 $?
check "one job succeeds" "500M COMPLETED;" "$(jobs_since "$start")"

if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "All checks passed"
