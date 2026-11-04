from snakemake import __version__ as SNAKEMAKE_VERSION

# A project set up with an earlier version has no such line in its config/.docker.yml
REPORT_IMAGE = docker.get("report", "docker://rocker/verse:4.4.2")


def report_rule_table(module):
    """The rules of a module that write a benchmark, for its report: name|benchmark pattern|uses /dev/shm.
    The generic helper rules run for every module, and the report finds their files in the module's folder."""
    rows = []
    for r in workflow.rules:
        if r.name.startswith((f"{module}__", "helpers__")) and r.benchmark:
            uses_shm = "shm" in (r.shellcmd or "").lower()
            rows.append(f"{r.name}|{r.benchmark}|{int(uses_shm)}")
    return ";".join(rows)
