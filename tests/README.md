# Tests

Checks to run when you change the pipeline. Part I of the book explains these kinds of tests in the chapter "Testing a workflow".

| Test | What it proves | What it needs | How long |
|------|----------------|---------------|----------|
| `escalation/run_test.sh` | A failing command stops its rule, and a failed job escalates to a bigger SLURM job with one attempt per resource set | Docker | About 10 minutes |

The escalation test runs the real `workflow/Snakefile` and rules on a real SLURM cluster in a container (`book/examples/minicluster`), with a stand-in for one tool. It needs no data or databases.
