#!/usr/bin/env python3
"""Check the resource sets against the published limits of CSC's Roihu.

Usage: check_resource_sets.py [config.yaml] [escalation.yaml]

SLURM refuses a job that asks for more than a node has, or for something it doesn't have, with
"Requested node configuration is not available", and a job with too long a time limit may wait forever.
That only shows up when the job is submitted, which can be hours into a run. So this checks all the
sets, and that each set named in escalation.yaml exists.

The limits are from https://docs.csc.fi/computing/running/batch-job-partitions/ on 2026-11-05. If you
run on another system, change them here too. Needs PyYAML, which comes with Snakemake.
"""
import sys
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[2]
MIB_PER_GIB = 1024

# hours, cores per job, GiB per job, whether a job gets whole nodes, and whether --gres=nvme exists
LIMITS = {
    "small": (72, 384, 1500, False, False),
    "longrun": (240, 192, 1500, False, False),
    "medium": (36, 384, 744, True, False),
    "hugemem": (36, 128, 6037, False, True),
    "hugemem_longrun": (240, 128, 6037, False, True),
}
HUGEMEM_GIB_PER_CORE = 6037 / 128


def problems_of(name, values):
    partition = values["partition"]
    if partition not in LIMITS:
        return [f"partition {partition} doesn't exist"]
    hours, cores, gib, whole_node, has_nvme = LIMITS[partition]
    found = []
    if values["runtime"] > hours * 60:
        found.append(f"{values['runtime']} minutes, and {partition} allows {hours * 60}")
    if values["cpus"] > cores:
        found.append(f"{values['cpus']} cores, and {partition} allows {cores}")
    if values["mem_mb"] > gib * MIB_PER_GIB:
        found.append(f"{values['mem_mb']} MB, and {partition} allows {gib} GiB")
    if whole_node and values["cpus"] != cores:
        found.append(f"{values['cpus']} cores, and {partition} takes only whole nodes of {cores}")
    if values["nvme"] and not has_nvme:
        found.append(f"--gres={values['nvme']}, and {partition} has no such resource")
    if partition.startswith("hugemem") and values["mem_mb"] > values["cpus"] * HUGEMEM_GIB_PER_CORE * MIB_PER_GIB:
        found.append(f"{values['mem_mb']} MB with {values['cpus']} cores, and {partition} ties the memory to the cores")
    return found


def main():
    config_file = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO / "config/config.yaml"
    escalation_file = Path(sys.argv[2]) if len(sys.argv) > 2 else REPO / "config/escalation.yaml"
    sets = yaml.safe_load(config_file.read_text())["resource_sets"]
    failures = 0
    for name, values in sets.items():
        found = problems_of(name, values)
        print(("FAIL" if found else "ok  "), name, "; ".join(found))
        failures += len(found)
    escalation = yaml.safe_load(escalation_file.read_text())
    for rule, order in escalation.items():
        for name in str(order).replace(" ", "").split(","):
            if name not in sets:
                print("FAIL", rule, "asks for the set", name, "which doesn't exist")
                failures += 1
    if failures:
        sys.exit(f"{failures} problems")
    print(f"All {len(sets)} sets fit, and all {len(escalation)} rules in {escalation_file.name} name existing sets.")


if __name__ == "__main__":
    main()
