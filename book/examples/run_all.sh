#!/usr/bin/env bash
# Build the mini cluster, start it and run all examples of the book in it (needs Docker).
# Usage: run_all.sh [example name ...]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
docker build -q -t book-minicluster "$here/minicluster" > /dev/null
docker rm -f minicluster > /dev/null 2>&1 || true
docker run -d --name minicluster --hostname localhost --privileged -v "$here":/examples book-minicluster sleep infinity > /dev/null
docker exec minicluster start-cluster > /dev/null
docker exec minicluster python3 /examples/make_data.py
docker exec -e PATH=/opt/snakemake/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin minicluster python3 /examples/run_examples.py /examples "$@"
