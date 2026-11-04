#!/usr/bin/env bash
# Test where the DIAMOND rules take their database from. Needs Docker, and takes a few minutes:
# it runs the real rules with a stand-in for diamond, and no database or data is needed.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
docker build -q -t book-minicluster "$repo/book/examples/minicluster" > /dev/null
docker run --rm -v "$repo":/pipeline:ro book-minicluster bash /pipeline/tests/diamond_staging/inside_container.sh
