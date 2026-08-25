#!/usr/bin/env python3
"""Report a SLURM job's status to Snakemake as "running"/"success"/"failed".

Adapted from the status-checking approach used by SLURM Snakemake executor
profiles (see https://github.com/ManavalanG/slurm), which query `sacct` with
a fallback to `scontrol` for jobs sacct hasn't indexed yet.
"""
import logging
import re
import shlex
import subprocess as sp
import sys
import time

logger = logging.getLogger(__name__)

MAX_ATTEMPTS = 20

FAILED_STATES = {
    "BOOT_FAIL", "OUT_OF_MEMORY", "DEADLINE", "FAILED",
    "NODE_FAIL", "PREEMPTED", "TIMEOUT", "SUSPENDED",
}
# CANCELLED can carry a suffix (e.g. "CANCELLED by 1234"); handled separately below.


def query_sacct(jobid):
    out = sp.check_output(shlex.split(f"sacct -P -b -j {jobid} -n"))
    lines = out.decode().strip().split("\n")
    return {line.split("|")[0]: line.split("|")[1] for line in lines}


def query_scontrol(jobid):
    out = sp.check_output(shlex.split(f"scontrol -o show job {jobid}"))
    match = re.search(r"JobState=(\w+)", out.decode())
    return {jobid: match.group(1)}


def job_state(jobid):
    for attempt in range(MAX_ATTEMPTS):
        try:
            return query_sacct(jobid)[jobid]
        except (sp.CalledProcessError, IndexError, KeyError) as exc:
            logger.error("sacct lookup failed: %s", exc)
        try:
            return query_scontrol(jobid)[jobid]
        except sp.CalledProcessError as exc:
            logger.error("scontrol lookup failed: %s", exc)
            if attempt >= MAX_ATTEMPTS - 1:
                return None
            time.sleep(1)
    return None


def main():
    jobid = sys.argv[1]
    state = job_state(jobid)

    if state is None or state.startswith("CANCELLED") or state in FAILED_STATES:
        print("failed")
    elif state == "COMPLETED":
        print("success")
    else:
        print("running")


if __name__ == "__main__":
    main()
