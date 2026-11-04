# Tests

Checks to run when you change the pipeline. Part I of the book explains these kinds of tests in the chapter "Testing a workflow".

| Test | What it proves | What it needs | How long |
|------|----------------|---------------|----------|
| `escalation/run_test.sh` | A failing command stops its rule, and a failed job escalates to a bigger SLURM job with one attempt per resource set | Docker | About 10 minutes |
| `diamond_staging/run_test.sh` | The DIAMOND rules take their database from the right place in each storage situation, including when nothing can be copied | Docker | A few minutes |
| `krona/run_test.sh` | The options of the Krona rule draw a Kraken2 report correctly | Docker, a download of 30 MB | Under a minute, plus the container |
| `real_tools/check_results.py <project>` | The results of a project with the real tools are the same as those stored in `real_tools/expected.tsv` | A finished project | Under a minute |
| `real_tools/run_test.sh <subsets> <new project>` | The same, from scratch: the pipeline's rules with the real tools on 1 million read pairs per sample, up to the MAG catalogue, and some annotation | Docker, the example reads, about 40 GB | Hours under emulation |

The escalation test runs the real `workflow/Snakefile` and rules on a real SLURM cluster in a container (`book/examples/minicluster`), with a stand-in for one tool. It needs no data or databases. The DIAMOND test runs the real rules with a stand-in for `diamond`, in the same container. The Krona test uses the real tool in its real container, and it reads its options from the rule.

`real_run/` isn't a test yet: it runs the whole pipeline on a real cluster with the example data and records the run, see `real_run/README.md`. The expected results of the tools with large databases will come from such a run.
