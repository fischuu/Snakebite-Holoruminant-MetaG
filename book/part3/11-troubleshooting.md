# Common problems {#sec-troubleshooting}

Something will fail. With this many tools, this isn't a sign that you did anything wrong. This chapter shows how to find the cause, and it lists the problems you're most likely to meet. @sec-debugging explains the Snakemake side in general.

## How to find out what happened

Work through these from the outside in:

1. **Snakemake's output.** Look for the `Error in rule` block. It tells you the rule, the wildcards, the log files and the SLURM job number.
2. **The rule's log**, the file under `log:` in the block. This is what the tool itself said, and it's usually where the answer is. If the rule uses the `.try` pattern, look at `{log}.try1` as well, as a successful run renames this file, but a failed one doesn't.
3. **The job log**, in `.snakemake/slurm_logs/rule_<name>/<wildcards>/<jobid>.log`. This holds what Snakemake printed within the job. It's useful if the rule's log is empty.
4. **SLURM's view**, which tells you whether the job was killed:

```bash
sacct -j <jobid> --format=JobID,State,ExitCode,ReqMem,MaxRSS,Elapsed,Timelimit
```

A state of `OUT_OF_MEMORY` or `TIMEOUT` tells you what to do next, and in these cases the tool's log simply stops without any error message.

## Quick table

| What you see | Likely cause | What to do |
|--------------|--------------|------------|
| `Invalid account or account/partition combination` | `slurm_account` in the profile, or a partition in `resource_sets` | See @sec-setup |
| `OUT_OF_MEMORY` in `sacct`, a log that just stops | Too little memory | Add a larger set to the rule in `escalation.yaml` |
| `TIMEOUT` | Too little time | Use a set with more time, such as `longrun` |
| A file "doesn't exist", but you can see it | The folder isn't bound into the container | Add it to `--singularity-args` |
| `No space left on device` | Temporary folder, `/dev/shm`, or quota | See below |
| `LockException` | A previous Snakemake died | `--unlock`, see below |
| `IncompleteFilesException` | A job was killed halfway | `--rerun-incomplete` |
| `MissingOutputException` | The file system is slow, or the tool wrote elsewhere | Check the log, raise `--latency-wait` |
| `MissingInputException` | A file isn't there and no rule makes it | Check the paths in `samples.tsv` and `features.yaml` |
| `Invalid sample sheet` | A library or a file is listed twice | The message tells you which |
| An error about the CRAM header | Long contig names | `out_type: bam` in `params.yaml` |
| `gzip: ... unexpected end of file`, or `Error occurs when reading inputs` from MEGAHIT | A truncated file, for example clean reads from a version before 0.4.69 | Delete it and what's built on it, see `RELEASE_NOTES` |
| An assembly without bins | Too little data, or a real error | See below |
| `dRep wrote no genomes`, with `!!! checkM failed !!!` above it | CheckM, inside dRep, ran out of memory | Add a larger set to `assemble__drep__run` |
| `ValueError: The number of observations cannot be determined on an empty distance matrix` from dRep | There's only one genome | Nothing to dereplicate. See below |
| Many lines `[W::cram_encode_container] Failed to build reference, switching to non-ref mode` | `assemble__bowtie2__map` writes CRAM without a reference | Harmless: the file just stores the sequences itself |

## Memory

The most common failure. The values in `resource_sets` are starting points, and most rules have only one set, so a job that runs out of memory stops the pipeline rather than trying again with more.

To let a rule try again with more, extend its line in `config/escalation.yaml`:

```
assemble__metaspades__run: large, highmem
```

Check the memory settings given to the tools too: `samtools sort` gets a value **per thread**, in `params.yaml`, and if this multiplied by the threads is more than the job has, the job gets killed, however large the set.

Snakemake restarts the failed job with the next set when you start the pipeline again, or within the same run, if it's still going.

## Time

Long jobs can hit the limit of a partition. On Roihu, `small` allows 3 days, and `longrun` allows 10. The sets `longrun` and `highmem_longrun` are for that. Rules like metaSPAdes on a big co-assembly, MaxBin2 and REMAG are the usual candidates.

## Containers can't see a file

The tools run in containers, and they see only folders that are bound. The list is in the run script, under `--singularity-args`. If you link `resources` or `reads` to another place, that place has to be bound too. From the login node, the link looks fine, so this is confusing at first.

A related trap is `$TMPDIR`. The run script binds the project's `tmp/` to `/tmp` in the container, while SLURM often sets `$TMPDIR` to a path on the real `/tmp` of the node, and this doesn't exist in the container. Programs that use it fail, often deep inside another program. Several rules set their own `TMPDIR` for this reason: those of MAGScoT, Bakta, CAMPER and DRAM. The comments in these rules explain it. If you see such an error in another rule, this is the first thing to check.

## Disk space

`No space left on device` can have several sources, and the error rarely says which:

| Where | Check | Fix |
|-------|-------|-----|
| Your quota in the project | `df`, or the quota command of your cluster | Remove old results |
| The home folder | Apptainer's and Snakemake's caches | Set `APPTAINER_CACHEDIR` and `XDG_CACHE_HOME` in the run script |
| The project's `tmp/` | `du -sh tmp` | Remove what killed jobs left behind |
| `/dev/shm` on the node | The log of the rule | Use the set `full_node`, or set `kraken2_shm` and the like to `"False"` |
| The local disk | `$TMPDIR`, with 20 GiB in `small` and `longrun`, and 600 GiB in `medium` | Use `medium`, which costs a whole node, or leave the database where it is with `copy_dbs: "False"` |

## Starting again after a problem

**`LockException`.** Snakemake locks the folder while it runs. If it gets killed, the lock stays. Check that no other run is active, and then:

```bash
bash run_Snakebite-Holoruminant-MetaG.sh --unlock
```

**`IncompleteFilesException`.** Some files may be broken because a job was killed. Add `--rerun-incomplete`, and Snakemake makes them again.

**Jobs still running.** If you stop Snakemake, the jobs already in SLURM carry on. Look at `squeue --me`, and cancel them with `scancel` if you want to start over.

**Things that are rerun without need.** Snakemake reruns a rule if its code, its parameters or its input changed. After an update of the pipeline, this can mean a lot of jobs. Look at the reason in a dry run, as @sec-reruns explains. If you know that the results are still valid, `--rerun-triggers mtime` limits the reasons to changed files.

## Problems of single rules

### Kraken2 or DIAMOND: "database too large"

The rules fail on purpose if the database fits neither in `/dev/shm` nor on the local disk, as @sec-module-read-annotate explains. Give the rule a set with more local disk, or set `copy_dbs: "False"`.

For Kraken2, the database then runs from the network disk, and this can get very slow. Also, look out for leftover copies in `/dev/shm` from killed jobs.

### eggNOG-mapper: waiting forever

`contig_annotate__eggnog_orthology_chunk` waits while another job copies the database. If this other job was killed during the copy, the folder `$DATA_DIR/.lock` stays there and other jobs on that node wait until their time limit runs out. In the log, the last line is `Another job is copying the DB, waiting...`. Cancel the jobs, and let the node be cleaned up, or use `copy_dbs: "False"`.

### MAGScoT or dRep: no bins

With little data, this can be a valid result. The rule of MAGScoT catches a failure and continues with empty tables, which also hides real errors. Read `results/assemble/magscot/{assembly_id}/magscot.log`. dRep can't run on no genomes, and it also can't run on a single one. With one genome, you could lower `threshold` under `assemble: magscot` in `params.yaml` to let more bins through, as @sec-tutorial does for its small data, but judge those bins with care.

If all assemblies are affected, check the mapping rate and the Nonpareil coverage. These usually explain it.

### DRAM: a confusing error in `distill`

A failure in the annotation step can surface later. If `DRAM.py distill` complains about an empty file, then look at the log of the annotation first, and in particular at tRNAscan-SE. See "Containers can't see a file" above.

### `mag_annotate__proteinortho`

It needs at least two assemblies. Run the other tools one by one for a project with a single assembly.

### `read_annotate__diamond__summarise`

It fails if there's no R script for your database's name, as @sec-tool-diamond explains.

### Pandas errors at the start

Some combinations of Python and Pandas fail in strange ways. `docs/02-Installation.md` suggests a version that works.

## Failures that didn't exist before

Since version 0.4.68, a failing command stops its rule. Before that, from September 2026 on, a rule could ignore a failing command, and it only failed when its last command failed. @sec-strict-mode explains the background. So a rule that always "worked" can now stop with an error. That's the point, and the error was there before, only hidden. Read the log, and take the first error you find seriously.

## Asking for help

If you open an issue on GitHub, please give the rule, its log, the output of `sacct` for the job, the version from `CHANGELOG`, and your changes to the configuration. Don't paste data or paths that you can't share.

## Summary

- Read the rule's log first, then ask `sacct` whether the job was killed.
- Most failures are about memory, time, temporary space or a folder that the containers can't see.
- A failed run can be continued: `--unlock`, `--rerun-incomplete`, and start it again.
- A strict rule that fails is telling you about a real problem.
