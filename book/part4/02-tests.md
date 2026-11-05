# The tests in the repository {#sec-tests-in-repo}

`tests/` holds checks to run when you change the pipeline, and `tests/README.md` lists them. @sec-testing explains the different kinds of tests in general.

## The escalation test

`tests/escalation/run_test.sh` needs only Docker. It runs the real `workflow/Snakefile` and rules on a real SLURM cluster in a container, with a stand-in `bgzip` that fails when a job has too little memory. It checks that a failing command stops its rule, that a rule with two resource sets gets a new and bigger SLURM job, that no retry happens inside a job, that each resource set gets one attempt, and that a rule with one resource set isn't retried. It takes about ten minutes, most of which is Snakemake waiting between its status checks.

## The DIAMOND test

`tests/diamond_staging/run_test.sh` needs only Docker. It runs the real rules `read_annotate__diamond__assign` and `contig_annotate__diamond__assign` with a stand-in for `diamond`. It checks where the database comes from in each situation: without any fast storage, with one and with two resource sets, with `copy_dbs: "False"`, and with a copy in `/dev/shm` or on the local disk. On the rules before version 0.4.69, 8 of its checks fail.

## The Krona test

`tests/krona/run_test.sh` uses the real Krona in its container with the pipeline's taxonomy, and it reads the options from the rule. It draws a small report written by hand, and checks that each organism has its reads. On the rule before version 0.4.69, all 4 of its checks fail.

## The real results

`tests/real_tools/` stores the numbers from the run in @sec-tutorial as a test. It has two parts.

`check_results.py <project>` reads 41 numbers from the results of a project and compares them with `expected.tsv`. These include the reads before and after fastp, the reads on the host, the clean reads, the contigs, bases and bins of each assembly, the genomes of dRep, the genes from Prodigal and the contigs classified by Tiara. It only takes a moment. A file that's missing or cut off counts as a failure.

`run_test.sh <subsets> <new project>` makes such a project from scratch and then runs the check. This takes hours under emulation.

Each number has a tolerance in `expected.tsv`. It's 0 where a tool gives the same result each time, 5% for the assemblies, and 50% for the number of bins.

When a difference is right, because you meant to change something, run `check_results.py <project> --write`, and say why in the commit. Look at the differences first, as this is the whole point of the test. When a number changes, ask why.

It runs on the small data of @sec-tutorial, so it can't say anything about the tools in @sec-tutorial-waiting.

## The complete run

`tests/real_run/` isn't a test yet. It runs the whole pipeline on a real cluster with the example data, stage by stage, and packs a record of the run into one small archive. The expected results of the tools with large databases will come from this, in the same way as above.
