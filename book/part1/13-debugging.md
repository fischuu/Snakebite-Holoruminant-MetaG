# When things go wrong {#sec-debugging}

You will spend more time with failed runs than with successful ones, and that's normal. Most errors fall into a few families, and once you
recognise them they take seconds to solve. This chapter provokes each of them on purpose. The example is in
`book/examples/snakemake/09_errors/`, with one small Snakefile per mistake.

## A way of reading errors

Snakemake's messages get long, and the useful line can be anywhere in them. Three habits help:

1. **Read the first error, not the last line.** The final lines usually only say that something failed.
2. **Look for the name of the exception**, the word ending in `Error` or `Exception`. It tells you the family.
3. **Find the job's own log file.** The message from Snakemake says that a command failed, and the log says why.

## Errors in the Snakefile

These appear immediately, before any job runs.

### A typo in a keyword

```text
$ snakemake -s Snakefile.typo --cores 1
SyntaxError in file "/scratch/project_demo/examples/09_errors/Snakefile.typo", line 3:
Unexpected keyword outptu in rule definition:
None
[exit code 1]
```

The file and line number are right there. Syntax errors usually are this helpful, although the line number can point to the line after the true
mistake, for example after a missing comma or quote. Bad indentation falls into this family too.

### Single braces in a command

This rule uses `awk` with single braces:

```python
    shell:
        "zcat {input} | awk '{print $1}' | wc -l > {output}"
```

```text
$ snakemake -s Snakefile.braces --cores 1
[...]
RuleException in rule count in file "/scratch/project_demo/examples/09_errors/Snakefile.braces", line 1:
NameError: The name 'print $1' is unknown in this context. Please make sure that you defined that variable. Also note that braces not used for variable access have to be escaped by repeating them, i.e. {{print $1}}
zcat {input} | awk '{print $1}' | wc -l > {output}
[exit code 1]
```

Snakemake took `{print $1}` for a variable, and tells you exactly what to do. You will make this mistake, probably more than once. The error only
appears when the job is about to run, so it may come hours into a workflow. A dry run with `-p` catches it early, because it has to build the command
to print it.

## Errors in the plan

These appear while Snakemake builds the DAG, so a dry run shows them too.

### `MissingInputException`

Snakemake found a rule for your file, but the input doesn't exist and no rule can make it. See @sec-wildcards. Check the path and sample names.

### `MissingRuleException`

No rule can make a file with this name. Also see @sec-wildcards. Compare the name character by character with the rule's output pattern.

### `AmbiguousRuleException`

Two rules can make the same file, and Snakemake won't guess:

```text
$ snakemake -s Snakefile.ambiguous --cores 1
[...]
AmbiguousRuleException:
Rules from_forward and from_reverse are ambiguous for the file results/sampleA.txt.
Consider starting rule output with a unique prefix, constrain your wildcards, or use the ruleorder directive.
Wildcards:
	from_forward: sample=sampleA
	from_reverse: sample=sampleA
Expected input files:
	from_forward: data/sampleA_R1.fastq.gz
	from_reverse: data/sampleA_R2.fastq.gz
Expected output files:
	from_forward: results/sampleA.txt
	from_reverse: results/sampleA.txt
[exit code 1]
```

The usual solution is to give each rule its own output folder. This pipeline does that consistently, with one folder per tool. It uses
`wildcard_constraints` where patterns could still overlap.

## Errors while a job runs

### The command failed

Here is a rule whose command fails on purpose:

```python
rule count:
    input:
        "data/sampleA_R1.fastq.gz",
    output:
        "results/count.txt",
    log:
        "logs/count.log",
    shell:
        """
        exec > {log} 2>&1
        echo "Working on {input}"
        zcat {input} > {output}
        echo "Something goes wrong now"
        false
        """
```

```text
$ snakemake -s Snakefile.fails --cores 1
[...]
Error in rule count:
    message: None
    jobid: 0
    input: data/sampleA_R1.fastq.gz
    output: results/count.txt
    log: logs/count.log (check log file(s) for error details)
    shell:
        
        exec > logs/count.log 2>&1
        echo "Working on data/sampleA_R1.fastq.gz"
        zcat data/sampleA_R1.fastq.gz > results/count.txt
        echo "Something goes wrong now"
        false
        
        (command exited with non-zero exit code)
Removing output files of failed job count since they might be corrupted:
results/count.txt
[...]
WorkflowError:
At least one job did not complete successfully.
[exit code 1]
```

The message gives you the rendered command and the log's path. Two things to take from this:

**Snakemake removes the output of a failed job.** The file `results/count.txt` was written, and it is deleted because it may be incomplete. If you want
to look at it for debugging, run with `--keep-incomplete`.

**The log file stays**, and it has the answer:

```text
$ cat logs/count.log
Working on data/sampleA_R1.fastq.gz
Something goes wrong now
```

A useful debugging step comes out of this as well: you can copy the command from the message and run it yourself, in the same folder. On a cluster, ask for
an interactive session first. If the rule uses a container, run it in that too, as @sec-containers shows.

### The command worked, but the output is missing

This rule writes to a different file than it promised:

```python
    output:
        "results/count.txt",
    shell:
        "zcat {input} | wc -l > results/typo.txt"
```

```text
$ snakemake -s Snakefile.nooutput --cores 1 --latency-wait 1
[...]
Waiting at most 1 seconds for missing files:
results/count.txt (missing locally)
MissingOutputException in rule count in file "/scratch/project_demo/examples/09_errors/Snakefile.nooutput", line 1:
Job 0 completed successfully, but some output files are missing. Missing files after 1 seconds. This might be due to filesystem latency. If that is the case, consider to increase the wait time with --latency-wait:
results/count.txt (missing locally, parent dir contents: typo.txt)
[...]
```

This is helpful: it lists what *is* in the folder. On a cluster it can have two causes. Either the tool named the file differently than you expected, for example by adding its
own ending. Or the shared disk is slow, and the file hasn't appeared yet, which is why the pipeline uses `--latency-wait 60`. If a file shows up when you look a minute later, it was the latter.

## After a crash: incomplete files and locks

What happens when Snakemake itself dies, because of a lost connection, a killed login session or the end of a time limit? We can simulate this by killing it on purpose. This rule takes eight seconds:

```python
rule slow:
    output:
        "results/slow.txt",
    shell:
        """
        echo "started" > {output}
        sleep 8
        echo "finished" >> {output}
        """
```

We start it, and kill Snakemake after four seconds with `kill -9`, which gives it no chance to clean up:

```text
$ snakemake -s Snakefile.slow --cores 1 > /dev/null 2>&1 &
  sleep 4
  kill -9 $!
  sleep 1
  cat results/slow.txt
started
```

An output exists, and it is incomplete. A normal failure would have removed it, but this time nothing could. So what does the next run do?

```text
$ snakemake -s Snakefile.slow --cores 1
Assuming unrestricted shared filesystem usage.
host: localhost
Building DAG of jobs...
IncompleteFilesException:
The files below seem to be incomplete. If you are sure that certain files are not incomplete, mark them as complete with

    snakemake --cleanup-metadata <filenames>

To re-generate the files rerun your command with the --rerun-incomplete flag.
Incomplete files:
results/slow.txt
[exit code 1]
```

Snakemake marks an output as "in progress" when a job starts, and removes the mark when the job finishes. So it knows that this file is suspicious, and won't build on it. We follow its advice:

```text
$ snakemake -s Snakefile.slow --cores 1 --rerun-incomplete
Building DAG of jobs...
LockException:
Error: Directory cannot be locked. Please make sure that no other Snakemake process is trying to create the same files in the following directory:
/scratch/project_demo/examples/09_errors
If you are sure that no other instances of snakemake are running on this directory, the remaining lock was likely caused by a kill signal or a power loss. It can be removed with the --unlock argument.
[exit code 1]
```

This is the second consequence. A running Snakemake locks its folder, so that two runs can't write the same files. The killed one couldn't remove its lock. **Before you unlock, check that no Snakemake is
really still running**, for example in a tmux session you forgot about. Once you are sure:

```text
$ snakemake -s Snakefile.slow --unlock
Building DAG of jobs...
Unlocked working directory.

$ snakemake -s Snakefile.slow --cores 1 --rerun-incomplete --quiet
[...]

$ cat results/slow.txt
started
finished
```

There is a further lesson here. Between the kill and the unlock, the example waits for six seconds, and when we look at the file during that wait, it says "started, finished". The killed Snakemake's command had
kept running on its own, and finished writing the file. **Killing Snakemake doesn't kill the jobs it started.** On a cluster, its SLURM jobs also keep running. So look with `squeue` and cancel them with `scancel`
before starting again. If you don't, two jobs may write the same file.

To stop a run cleanly, press Ctrl-C once and wait. Snakemake then cancels its jobs and cleans up.

## When nothing goes wrong, but something did: strict mode {#sec-strict-mode}

The worst kind of failure gives no error message at all. @sec-linux explained that Snakemake runs commands in strict mode, with `set -euo pipefail`, so that a failing command stops the rule. It does this by putting those words in front of each command, and that makes it easy to lose by accident.

The directive `shell.prefix` puts something of your own in front of each command. It looks harmless, and it is a convenient way to give all rules a helper function. But it **replaces** Snakemake's default prefix instead of adding to it:

```python
# This replaces Snakemake's default prefix, and with it the strict mode
shell.prefix('debug() {{ echo "[DEBUG] $*" >&2; }}; ')


rule silent_failure:
    output:
        "results/silent.txt",
    shell:
        """
        false | cat > {output}
        echo "The first line failed, and this still runs" >> {output}
        """
```

The first command fails, the rule continues, and Snakemake reports a success:

```text
$ snakemake -s Snakefile.prefix --cores 1 --quiet
[...]
$ cat results/silent.txt
The first line failed, and this still runs
```

Imagine that this first command is an assembler that ran out of memory, and the second line moves a log file. The job counts as `COMPLETED`, the next rules start on an incomplete result, and nothing tells you. The only trace is in the rule's log.

The fix is to repeat the strict mode in your prefix:

```python
shell.prefix('set -euo pipefail; debug() {{ echo "[DEBUG] $*" >&2; }}; ')
```

Now the same rule fails, as it should, and the second line never runs:

```text
$ snakemake -s Snakefile.strict --cores 1 --quiet 2>&1 | grep -E 'Error in rule|exit status' | sort -u
        echo "This never runs" >> results/strict.txt' returned non-zero exit status 1.

$ ls results/strict.txt || true
ls: cannot access 'results/strict.txt': No such file or directory
```

This isn't a made-up example. This pipeline had that bug from September to November 2026, and the `RELEASE_NOTES` describe how to check results from such a version. A dry run can't find this kind of bug, and neither can a stand-in tool that never fails. It takes a test in which something fails on purpose (@sec-testing).

## What strict mode doesn't see: `>(...)` {#sec-process-substitution-trap}

There's one more kind of silent failure, and it's a nasty one. @sec-linux introduced process substitution. It's fine for reading, as in `<(zcat file)`. For writing, it hides a trap:

```bash
samtools fastq -1 >(pigz > reads_1.fq.gz) -2 >(pigz > reads_2.fq.gz) input.bam
```

Bash starts the two `pigz` processes on the side, and **it doesn't wait for them**. When `samtools` finishes, the command counts as finished, while `pigz` may still be writing. Strict mode doesn't help, since Bash doesn't look at their exit status either. So the job ends, Snakemake finds the output files, and everything looks fine. But if the job's processes are then stopped, the file is cut off.

This pipeline had exactly this bug until version 0.4.69. On a busy cluster, it would only have struck now and then, and it was only found when a real run in a container failed every time: a container stops all its processes the moment the main one ends.

When you write a rule, write files in one of these ways:

```bash
# The tool compresses by itself
samtools fastq -c 9 -1 reads_1.fq.gz -2 reads_2.fq.gz input.bam

# Or a plain pipe, which Bash waits for, and which strict mode checks
kraken2 --db db reads.fq | pigz > output.gz
```

`gzip -t file.gz` tells you whether a compressed file is complete, and it's a good check if you ever doubt a result.

## Why did this job run again? {#sec-reruns}

The most common surprise isn't an error: a dry run wants to redo work that you consider finished. The `reason` line tells you why. Since Snakemake 7.8, a job can rerun for any of these **rerun triggers**:

| Trigger | When it fires |
|---------|---------------|
| `mtime` | An input is newer than the output, or an output is missing |
| `params` | A value in `params:` changed |
| `input` | The list of input files changed |
| `software-env` | The container or conda environment changed |
| `code` | The rule's command or code changed |

We change one word in a rule's `params:`:

```text
$ sed -i 's/label="reads"/label="sequences"/' Snakefile.good
$ snakemake -s Snakefile.good --cores 1 --dry-run
[...]
rule count:
    input: data/sampleA_R1.fastq.gz
    output: results/count.txt
    jobid: 1
    reason: Params have changed since last execution: Union of exclusive params before and now across all output: before: 'reads' now: 'sequences'
[...]
Some jobs were triggered by provenance information, see 'reason' section in the rule displays above.
If you prefer that only modification time is used to determine whether a job shall be executed, use the command line option '--rerun-triggers mtime' (also see --help).
If you are sure that a change for a certain output file (say, <outfile>) won't change the result (e.g. because you just changed the formatting of a script or environment definition), you can also wipe its metadata to skip such a trigger via 'snakemake --cleanup-metadata <outfile>'.
Rules with provenance triggered jobs: count
[...]
```

This protects you from outdated results, but you sometimes know better. After a pipeline update that only reformatted some code, you don't want to redo weeks of assembly. There are two ways out.

Use only the file dates to decide, for this run:

```text
$ snakemake -s Snakefile.good --cores 1 --dry-run --quiet --rerun-triggers mtime
host: localhost
Building DAG of jobs...
Nothing to be done (all requested files are present and up to date).
```

Or tell Snakemake that the existing files are fine, with `--touch`. This updates dates and records, and runs nothing:

```text
$ snakemake -s Snakefile.good --cores 1 --touch --quiet
[...]
$ snakemake -s Snakefile.good --cores 1 --dry-run --quiet
host: localhost
Building DAG of jobs...
Nothing to be done (all requested files are present and up to date).
```

Only do this if you are sure that the existing results are still what you want. `--touch` will mark even wrong results as current, and nothing will warn you later.

## A checklist for a failed run

1. Find the first `Error in rule` in Snakemake's output, or at the end of the newest file in `.snakemake/log/`.
2. Read the job's log file, which the message names.
3. On a cluster, read the SLURM log as well. Its path is in the line "has been submitted with SLURM jobid".
4. Ask `sacct` how the job ended. `OUT_OF_MEMORY` and `TIMEOUT` mean that it needs more resources (@sec-slurm).
5. Copy the rendered command, and run it by hand in an interactive session.
6. After fixing it, run a dry run, and then start again. Add `--rerun-incomplete` if Snakemake asks for it.

@sec-troubleshooting collects the problems seen with this pipeline's tools.

## Summary

| Message | Meaning | What to do |
|---------|---------|------------|
| `SyntaxError` | A typo in the Snakefile | Look at the given line and the one before |
| `NameError: ... is unknown` | Single braces in a command | Double them |
| `MissingInputException` | Input is missing, and no rule makes it | Check paths and sample names |
| `MissingRuleException` | No rule makes this file | Compare with the output patterns |
| `AmbiguousRuleException` | Two rules make the same file | Give each its own folder or constrain wildcards |
| `MissingOutputException` | The command worked, but no output | Check the name, raise `--latency-wait` |
| `IncompleteFilesException` | A file from an interrupted run | `--rerun-incomplete` |
| `LockException` | Another or a dead Snakemake | Check, then `--unlock` |
| No message, but a wrong result | Strict mode lost through `shell.prefix` | Repeat `set -euo pipefail` in the prefix |
