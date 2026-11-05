#!/usr/bin/env bash
# Test that a failing rule escalates to a bigger SLURM job. Needs Docker, and takes a few minutes:
# it builds the mini cluster of the book, and runs the real pipeline code on it.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
docker build -q -t book-minicluster "$repo/book/examples/minicluster" > /dev/null
docker rm -f escalation-test > /dev/null 2>&1 || true
docker run -d --name escalation-test --hostname localhost --privileged -v "$repo":/pipeline book-minicluster sleep infinity > /dev/null
trap 'docker rm -f escalation-test > /dev/null 2>&1' EXIT
docker exec escalation-test start-cluster > /dev/null
docker exec escalation-test bash /pipeline/tests/escalation/inside_cluster.sh
